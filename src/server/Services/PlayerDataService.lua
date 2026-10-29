-- PlayerDataService: perfil persistente por jogador com trava de sessão.
--
-- * Um único documento por jogador (moedas, criaturas e progresso juntos) => operações atômicas.
-- * Trava de sessão via UpdateAsync: um servidor só grava se for o dono da trava,
--   evitando gravações conflitantes e duplicação de itens entre servidores.
-- * Salvamento automático periódico + salvamento rápido após operações importantes,
--   além do salvamento ao sair e no BindToClose (não depende só da saída).
-- * Toda alteração passa por PlayerDataService:Run, que faz cópia de segurança e
--   restaura o perfil se algo falhar no meio (nenhuma perda ou duplicação parcial).

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ProfileSchema = require(Shared.Logic.ProfileSchema)
local ProfileOps = require(Shared.Logic.ProfileOps)
local ClientView = require(Shared.Logic.ClientView)
local Income = require(Shared.Logic.Income)

local Remotes = require(script.Parent.Parent.Core.Remotes)

local PlayerDataService = {}

local STORE_NAME = "MutantFactory_Profiles_v1"
local LOCK_STALE_SECONDS = 15 * 60 -- trava considerada abandonada após 15 min sem renovação
local AUTOSAVE_INTERVAL = 60
local SOON_SAVE_DELAY = 3
local LOAD_ATTEMPTS = 6

local store = nil
local memoryMode = false -- sem acesso a DataStore (ex.: Studio sem permissão de API)

local sessions = {} -- [player] = { profile, dirty, saving, soonScheduled, valid, key }
local releasing = {} -- [userId] = true enquanto a gravação final de saída está em andamento
local rng = Random.new()
local listeners = { loaded = {}, changed = {} }
local lockProvider = nil -- function(player) -> { [uid] = true } (criaturas sendo carregadas)
local viewExtraProvider = nil -- function(player) -> dados do mundo para a fotografia

local function now()
	return DateTime.now().UnixTimestamp
end

-- ctx de uma operação: horário e RNG do SERVIDOR e as criaturas travadas (sendo roubadas).
function PlayerDataService.newContext(player)
	return {
		now = now(),
		locked = (lockProvider and player) and lockProvider(player) or {},
		rng = function()
			return rng:NextNumber()
		end,
	}
end

function PlayerDataService.setLockProvider(fn)
	lockProvider = fn
end

function PlayerDataService.setViewExtraProvider(fn)
	viewExtraProvider = fn
end

function PlayerDataService.now()
	return now()
end

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = deepCopy(v)
	end
	return out
end

local function keyFor(userId)
	return "p_" .. tostring(userId)
end

---------------------------------------------------------------------------
-- DataStore com tentativas
---------------------------------------------------------------------------

local function updateWithRetry(key, transform, attempts)
	attempts = attempts or 4
	local lastErr
	for i = 1, attempts do
		local ok, result = pcall(function()
			return store:UpdateAsync(key, transform)
		end)
		if ok then
			return true, result
		end
		lastErr = result
		warn(string.format("[PlayerData] UpdateAsync falhou (%d/%d) %s: %s", i, attempts, key, tostring(result)))
		task.wait(math.min(2 ^ i, 10))
	end
	return false, lastErr
end

---------------------------------------------------------------------------
-- carga
---------------------------------------------------------------------------

local function loadProfile(player)
	local key = keyFor(player.UserId)
	if memoryMode then
		return ProfileSchema.new(now()), nil
	end

	for attempt = 1, LOAD_ATTEMPTS do
		local lockedByOther = false
		local t = now()
		local ok, record = updateWithRetry(key, function(old)
			if old and old.lock and old.lock.jobId ~= game.JobId and (t - (old.lock.time or 0)) < LOCK_STALE_SECONDS then
				lockedByOther = true
				return nil -- cancela: outro servidor ainda é dono da sessão
			end
			old = old or {}
			old.lock = { jobId = game.JobId, time = t }
			return old
		end)
		if not ok then
			return nil, "datastore_error"
		end
		if not lockedByOther then
			local data = record and record.data
			if data == nil then
				data = ProfileSchema.new(t)
			end
			return data, nil
		end
		warn(string.format("[PlayerData] perfil de %s travado por outro servidor (tentativa %d)", player.Name, attempt))
		task.wait(5)
		if not player.Parent then
			return nil, "left"
		end
	end
	return nil, "locked"
end

---------------------------------------------------------------------------
-- gravação
---------------------------------------------------------------------------

local function saveSession(player, session, release)
	if memoryMode or not session.valid then
		return true
	end
	if session.saving then
		-- aguarda a gravação em andamento terminar
		local waited = 0
		while session.saving and waited < 30 do
			task.wait(0.25)
			waited = waited + 0.25
		end
	end
	session.saving = true
	local t = now()
	local snapshot = deepCopy(session.profile)
	session.dirty = false
	local lostLock = false
	local ok, err = updateWithRetry(session.key, function(old)
		if old and old.lock and old.lock.jobId ~= game.JobId then
			lostLock = true
			return nil -- outro servidor assumiu: não sobrescreve
		end
		return {
			data = snapshot,
			lock = (not release) and { jobId = game.JobId, time = t } or nil,
			savedAt = t,
			schema = ProfileSchema.Version,
		}
	end)
	session.saving = false
	if not ok then
		session.dirty = true
		warn("[PlayerData] não foi possível salvar " .. player.Name .. ": " .. tostring(err))
		return false
	end
	if lostLock then
		session.valid = false
		warn("[PlayerData] trava perdida para " .. player.Name .. "; sessão encerrada sem gravar")
		if player.Parent then
			player:Kick("Seus dados foram abertos em outro servidor. Entre novamente.")
		end
		return false
	end
	return true
end

function PlayerDataService.saveSoon(player)
	local session = sessions[player]
	if not session or session.soonScheduled then
		return
	end
	session.soonScheduled = true
	task.delay(SOON_SAVE_DELAY, function()
		session.soonScheduled = false
		if sessions[player] == session then
			saveSession(player, session, false)
		end
	end)
end

---------------------------------------------------------------------------
-- API para os serviços
---------------------------------------------------------------------------

function PlayerDataService.getProfile(player)
	local s = sessions[player]
	if s and s.valid then
		return s.profile
	end
	return nil
end

function PlayerDataService.isLoaded(player)
	return PlayerDataService.getProfile(player) ~= nil
end

function PlayerDataService.onLoaded(fn)
	table.insert(listeners.loaded, fn)
end

function PlayerDataService.onChanged(fn)
	table.insert(listeners.changed, fn)
end

-- Executa uma operação sobre o perfil. fn(profile, ctx) -> ok, dataOuCodigo
-- Retorna a resposta no formato do remote: { ok, data } ou { ok=false, error, message }.
-- opts = { important = bool (salva logo), silent = bool (não envia fotografia) }
function PlayerDataService.run(player, fn, opts)
	opts = opts or {}
	local session = sessions[player]
	if not session or not session.valid then
		return Remotes.fail("not_loaded", "Seus dados ainda estão carregando.")
	end
	local backup = deepCopy(session.profile)
	local ctx = PlayerDataService.newContext(player)
	local success, ok, data = pcall(fn, session.profile, ctx)
	if not success then
		session.profile = backup -- restaura tudo: falha parcial não altera nada
		warn("[PlayerData] operação falhou e foi revertida para " .. player.Name .. ": " .. tostring(ok))
		return Remotes.fail("server_error", "Erro no servidor. Nada foi alterado.")
	end
	if not ok then
		session.profile = backup -- validação falhou: garante que nada mudou
		return Remotes.fail(data, ProfileOps.Messages[data] or "Operação recusada.")
	end
	session.dirty = true
	if opts.important then
		PlayerDataService.saveSoon(player)
	end
	for _, l in ipairs(listeners.changed) do
		task.spawn(l, player, session.profile)
	end
	if not opts.silent then
		PlayerDataService.push(player)
	end
	return { ok = true, data = data }
end

-- Operação atômica sobre DOIS perfis do mesmo servidor (roubo).
-- fn(perfilA, perfilB, ctx) -> ok, dados. Se falhar, os dois perfis voltam como estavam.
-- Os dois são salvos logo em seguida (salvamento rápido).
function PlayerDataService.runPair(playerA, playerB, fn)
	local sa, sb = sessions[playerA], sessions[playerB]
	if not sa or not sa.valid or not sb or not sb.valid or sa == sb then
		return Remotes.fail("not_loaded", "Dados indisponíveis.")
	end
	local backupA, backupB = deepCopy(sa.profile), deepCopy(sb.profile)
	local ctx = PlayerDataService.newContext(nil)
	local success, ok, data = pcall(fn, sa.profile, sb.profile, ctx)
	if not success or not ok then
		sa.profile, sb.profile = backupA, backupB
		if not success then
			warn("[PlayerData] operação dupla revertida: " .. tostring(ok))
			return Remotes.fail("server_error", "Erro no servidor. Nada foi alterado.")
		end
		return Remotes.fail(data, ProfileOps.Messages[data] or "Operação recusada.")
	end
	for _, pair in ipairs({ { playerA, sa }, { playerB, sb } }) do
		pair[2].dirty = true
		PlayerDataService.saveSoon(pair[1])
		for _, l in ipairs(listeners.changed) do
			task.spawn(l, pair[1], pair[2].profile)
		end
		PlayerDataService.push(pair[1])
	end
	return { ok = true, data = data }
end

-- Envia a fotografia atualizada (agrupando várias alterações no mesmo quadro).
function PlayerDataService.push(player)
	local session = sessions[player]
	if not session or session.pushScheduled then
		return
	end
	session.pushScheduled = true
	task.defer(function()
		session.pushScheduled = false
		if sessions[player] ~= session or not session.valid or not player.Parent then
			return
		end
		Remotes.event("DataUpdated"):FireClient(player, PlayerDataService.buildView(player, session.profile))
	end)
end

function PlayerDataService.snapshot(player)
	local session = sessions[player]
	if not session or not session.valid then
		return nil
	end
	return PlayerDataService.buildView(player, session.profile)
end

function PlayerDataService.buildView(player, profile)
	local extra = viewExtraProvider and viewExtraProvider(player) or {}
	extra.name = player.DisplayName
	return ClientView.build(profile, now(), extra)
end

---------------------------------------------------------------------------
-- ciclo de vida
---------------------------------------------------------------------------

local function updateLeaderstats(player, profile)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return
	end
	ls.Moedas.Value = math.floor(profile.coins)
	ls.Renda.Value = math.floor(Income.totalRate(profile))
	ls.Roubos.Value = profile.stats.stolen
end

local function onPlayerAdded(player)
	-- se o jogador acabou de sair deste servidor, espera a gravação final
	local waited = 0
	while releasing[player.UserId] and waited < 30 do
		task.wait(0.5)
		waited = waited + 0.5
	end

	local data, err = loadProfile(player)
	if not player.Parent then
		return
	end
	if not data then
		if err == "locked" then
			player:Kick("Seus dados ainda estão em uso em outro servidor. Tente novamente em alguns minutos.")
		elseif err ~= "left" then
			player:Kick("Não foi possível carregar seus dados (serviço indisponível). Nada foi perdido; tente novamente.")
		end
		return
	end

	local t = now()
	ProfileSchema.migrate(data, t)
	local issues = ProfileSchema.validate(data, t)
	if #issues > 0 then
		warn("[PlayerData] integridade corrigida para " .. player.Name .. ": " .. table.concat(issues, "; "))
	end
	ProfileOps.refreshPeriods(data, t) -- a produção offline já está nos horários de cada criatura

	local session = {
		profile = data,
		dirty = true,
		saving = false,
		valid = true,
		key = keyFor(player.UserId),
	}
	sessions[player] = session

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, def in ipairs({ { "Moedas", "NumberValue" }, { "Renda", "NumberValue" }, { "Roubos", "IntValue" } }) do
		local v = Instance.new(def[2])
		v.Name = def[1]
		v.Parent = ls
	end
	ls.Parent = player
	updateLeaderstats(player, data)

	player:SetAttribute("DataLoaded", true)
	for _, l in ipairs(listeners.loaded) do
		task.spawn(l, player, data)
	end
	PlayerDataService.push(player)
end

local function onPlayerRemoving(player)
	local session = sessions[player]
	Remotes.clearPlayer(player)
	if not session then
		return
	end
	releasing[player.UserId] = true
	saveSession(player, session, true)
	sessions[player] = nil
	releasing[player.UserId] = nil
end

function PlayerDataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		if RunService:IsStudio() then
			-- testa permissão de API no Studio
			local okRead = pcall(function()
				store:GetAsync("__probe")
			end)
			if not okRead then
				memoryMode = true
				warn("[PlayerData] DataStore indisponível no Studio: usando MODO MEMÓRIA (nada será salvo). Ative 'Enable Studio Access to API Services'.")
			end
		end
	else
		memoryMode = true
		warn("[PlayerData] DataStore indisponível: MODO MEMÓRIA. " .. tostring(result))
	end

	PlayerDataService.onChanged(updateLeaderstats)
end

function PlayerDataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, p)
	end

	-- salvamento automático (também renova a trava de sessão)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, session in pairs(sessions) do
				if session.valid then
					task.spawn(saveSession, player, session, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, session in pairs(sessions) do
			pending = pending + 1
			task.spawn(function()
				saveSession(player, session, true)
				pending = pending - 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do
			task.wait(0.2)
		end
	end)

	Remotes.on("RequestData", "get", "Data", function(player)
		local view = PlayerDataService.snapshot(player)
		if not view then
			return Remotes.fail("not_loaded", "Seus dados ainda estão carregando.")
		end
		return { ok = true, data = view }
	end)
end

PlayerDataService.isMemoryMode = function()
	return memoryMode
end

-- usado por testes no Studio
PlayerDataService._sessions = sessions
PlayerDataService._uuid = function()
	return HttpService:GenerateGUID(false)
end

return PlayerDataService
