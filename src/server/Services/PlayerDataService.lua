-- Carrega e salva perfis no DataStore com TRAVA DE SESSÃO.
--
-- Registro salvo: { data = perfil, lock = { job, at } | nil, savedAt }.
-- * Carregar: UpdateAsync coloca a trava deste servidor. Se outro servidor tem a trava ativa
--   (renovada há menos de SessionLockTimeout s), espera e tenta de novo; se continuar travado,
--   o jogador é desconectado com aviso, SEM gravar nada.
-- * Falha de carregamento: o jogador é desconectado e o perfil nunca é salvo, então um perfil
--   vazio jamais sobrescreve dados existentes.
-- * Salvar: só grava se a trava ainda for deste servidor. Autosave renova a trava.
-- * Saída/desligamento: salva e libera a trava.
-- Sem acesso a API (Studio sem "Enable Studio Access to API Services") roda em MODO MEMÓRIA.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared.EconomyConfig)
local ProfileSchema = require(Shared.Logic.ProfileSchema)
local ProfileOps = require(Shared.Logic.ProfileOps)
local ClientView = require(Shared.Logic.ClientView)
local TimeUtil = require(Shared.Util.TimeUtil)
local Remotes = require(script.Parent.Parent.Core.Remotes)

local PlayerDataService = {}

PlayerDataService.StoreName = "MysteryMachine_Profiles_v1"
PlayerDataService.memoryMode = false

local JOB = game.JobId ~= "" and game.JobId or ("studio-" .. tostring(math.random(1, 1000000000)))
local store
local sessions = {} -- [player] = { data, dirty, saving, leaving }
local loadedCallbacks, changedCallbacks, leavingCallbacks = {}, {}, {}
local pendingPush = {}

local function key(userId)
	return "Player_" .. tostring(userId)
end

-- DataStore em memória com a mesma interface usada aqui (modo Studio sem API)
local function memoryStore()
	local data = {}
	return {
		UpdateAsync = function(_, k, fn)
			local result = fn(ProfileSchema.deepCopy(data[k]))
			if result ~= nil then
				data[k] = ProfileSchema.deepCopy(result)
			end
			return result
		end,
	}
end

local function openStore()
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(PlayerDataService.StoreName)
	end)
	if ok and s then
		local probeOk, err = pcall(function()
			return s:UpdateAsync("__probe", function(old)
				return old
			end)
		end)
		local msg = tostring(err)
		if probeOk or not (string.find(msg, "403") or string.find(msg, "API") or string.find(msg, "publish")) then
			return s
		end
	end
	PlayerDataService.memoryMode = true
	warn("[MYSTERY MACHINE] DataStore indisponível: MODO MEMÓRIA (nada será salvo). No Studio, publique o jogo e ative Game Settings > Security > Enable Studio Access to API Services.")
	return memoryStore()
end

local function lockIsActive(lock, now)
	return type(lock) == "table" and lock.job ~= JOB and type(lock.at) == "number" and now - lock.at < EconomyConfig.SessionLockTimeout
end

-- uma tentativa de carregar; retorna "ok", dados | "locked" | "error", mensagem
local function tryLoad(userId)
	local status, loaded = "error", nil
	local ok, err = pcall(function()
		store:UpdateAsync(key(userId), function(old)
			local now = TimeUtil.now()
			status, loaded = "error", nil
			if type(old) == "table" and lockIsActive(old.lock, now) then
				status = "locked"
				return nil -- não altera o registro do outro servidor
			end
			local record = type(old) == "table" and old or {}
			local data = record.data
			if data == nil then
				data = ProfileSchema.new()
			end
			record.data = data
			record.lock = { job = JOB, at = now }
			status, loaded = "ok", data
			return record
		end)
	end)
	if not ok then
		return "error", tostring(err)
	end
	return status, loaded
end

local function release(player, reason)
	sessions[player] = nil
	Remotes.clear(player)
	if reason and player.Parent then
		player:Kick(reason)
	end
end

local function load(player)
	local userId = player.UserId
	local status, data
	for attempt = 1, 6 do
		status, data = tryLoad(userId)
		if status == "ok" or not player.Parent then
			break
		end
		if status == "locked" then
			warn("[MYSTERY MACHINE] perfil de " .. player.Name .. " travado por outro servidor, aguardando (" .. attempt .. ")")
		else
			warn("[MYSTERY MACHINE] UpdateAsync falhou ao carregar " .. player.Name .. ": " .. tostring(data))
		end
		task.wait(math.min(2 ^ attempt, 8))
	end
	if status ~= "ok" then
		if player.Parent then
			if status == "locked" then
				player:Kick("Seus dados ainda estão abertos em outro servidor. Aguarde um minuto e entre novamente.")
			else
				player:Kick("Não foi possível carregar seus dados agora. Seu progresso está seguro: tente novamente em instantes.")
			end
		end
		return
	end
	local profile, fixes = ProfileSchema.reconcile(data)
	if #fixes > 0 then
		warn("[MYSTERY MACHINE] perfil de " .. player.Name .. " reparado: " .. table.concat(fixes, ", "))
	end
	ProfileOps.ensureDaily(profile, TimeUtil.now())
	local session = { data = profile, dirty = true }
	sessions[player] = session
	if not player.Parent then
		-- saiu durante o carregamento: grava e libera a trava
		PlayerDataService.save(player, true)
		sessions[player] = nil
		return
	end
	for _, fn in ipairs(loadedCallbacks) do
		task.spawn(fn, player, profile)
	end
	PlayerDataService.pushView(player)
end

-- grava o perfil; release = true libera a trava. Retorna true se gravou.
function PlayerDataService.save(player, releaseLock)
	local session = sessions[player]
	if not session then
		return false
	end
	local snapshot = ProfileSchema.deepCopy(session.data)
	local userId = player.UserId
	for attempt = 1, 3 do
		local lost = false
		local ok, err = pcall(function()
			store:UpdateAsync(key(userId), function(old)
				local now = TimeUtil.now()
				lost = false
				if type(old) == "table" and type(old.lock) == "table" and old.lock.job ~= JOB then
					lost = true
					return nil
				end
				return {
					data = snapshot,
					lock = (not releaseLock) and { job = JOB, at = now } or nil,
					savedAt = now,
				}
			end)
		end)
		if ok and lost then
			warn("[MYSTERY MACHINE] trava de " .. player.Name .. " pertence a outro servidor; gravação cancelada")
			if not releaseLock then
				release(player, "Seus dados foram abertos em outro servidor. Entre novamente.")
			end
			return false
		end
		if ok then
			session.dirty = false
			return true
		end
		warn("[MYSTERY MACHINE] UpdateAsync falhou ao salvar " .. player.Name .. " (" .. attempt .. "): " .. tostring(err))
		task.wait(attempt)
	end
	return false
end

function PlayerDataService.getProfile(player)
	local s = sessions[player]
	if s and not s.leaving then
		return s.data
	end
	return nil
end

function PlayerDataService.isLoaded(player)
	return PlayerDataService.getProfile(player) ~= nil
end

function PlayerDataService.loadedPlayers()
	local out = {}
	for player, s in pairs(sessions) do
		if not s.leaving then
			table.insert(out, player)
		end
	end
	return out
end

-- restaura uma cópia (usado quando uma operação falha no meio)
function PlayerDataService.restore(player, backup)
	local s = sessions[player]
	if s then
		for k in pairs(s.data) do
			s.data[k] = nil
		end
		for k, v in pairs(backup) do
			s.data[k] = v
		end
	end
end

function PlayerDataService.pushView(player)
	local profile = PlayerDataService.getProfile(player)
	if profile then
		Remotes.event("DataUpdated"):FireClient(player, ClientView.build(profile, TimeUtil.now()))
	end
end

-- perfil mudou: agenda o envio da fotografia (agrupa várias mudanças) e avisa os serviços
function PlayerDataService.markDirty(player)
	local s = sessions[player]
	if not s then
		return
	end
	s.dirty = true
	if pendingPush[player] then
		return
	end
	pendingPush[player] = true
	task.delay(0.1, function()
		pendingPush[player] = nil
		local profile = PlayerDataService.getProfile(player)
		if profile then
			for _, fn in ipairs(changedCallbacks) do
				fn(player, profile)
			end
			PlayerDataService.pushView(player)
		end
	end)
end

function PlayerDataService.onLoaded(fn)
	table.insert(loadedCallbacks, fn)
end

function PlayerDataService.onChanged(fn)
	table.insert(changedCallbacks, fn)
end

function PlayerDataService.onLeaving(fn)
	table.insert(leavingCallbacks, fn)
end

local function onRemoving(player)
	local s = sessions[player]
	if not s then
		Remotes.clear(player)
		return
	end
	s.leaving = true
	for _, fn in ipairs(leavingCallbacks) do
		pcall(fn, player, s.data)
	end
	PlayerDataService.save(player, true)
	sessions[player] = nil
	Remotes.clear(player)
end

function PlayerDataService.start()
	store = openStore()
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(onRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(load, player)
	end
	task.spawn(function()
		while true do
			task.wait(EconomyConfig.AutosaveInterval)
			for _, player in ipairs(PlayerDataService.loadedPlayers()) do
				task.spawn(PlayerDataService.save, player, false)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player, s in pairs(sessions) do
			if not s.leaving then
				pending = pending + 1
				task.spawn(function()
					s.leaving = true
					PlayerDataService.save(player, true)
					pending = pending - 1
				end)
			end
		end
		local waited = 0
		while pending > 0 and waited < 25 do
			waited = waited + task.wait(0.2)
		end
	end)
	if RunService:IsStudio() and not PlayerDataService.memoryMode then
		print("[MYSTERY MACHINE] DataStore ativo no Studio: o progresso deste teste será salvo.")
	end
end

PlayerDataService.JobId = JOB

return PlayerDataService
