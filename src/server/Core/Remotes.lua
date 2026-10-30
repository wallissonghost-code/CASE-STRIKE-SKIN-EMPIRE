-- Cria a pasta ReplicatedStorage.Remotes e centraliza o tratamento de pedidos do cliente.
--
-- Todo pedido (RemoteFunction) passa por: perfil carregado → requestId repetido (devolve a mesma
-- resposta sem repetir a operação) → limite de frequência → trava por jogador → operação com
-- cópia de segurança do perfil (restaurada se der erro no meio) → marca o perfil como alterado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileSchema = require(Shared.Logic.ProfileSchema)
local RateLimiter = require(script.Parent.RateLimiter)

local Remotes = {}

Remotes.Functions = { "RequestMachineUse", "InventoryAction", "UpgradeAction", "ProgressAction" }
Remotes.Events = { "MachineResult", "DataUpdated", "Notify", "LeaderboardUpdated" }

local folder
local handlers = {} -- [remoteName][action] = { fn, category }
local recent = {} -- [player] = { ids = {requestId = response}, order = {...} }
local busy = {} -- [player] = true durante uma operação
local dataService -- injetado por init (evita dependência circular)
local afterSuccess = {}

local MAX_RECENT = 30

local function remember(player, requestId, response)
	local r = recent[player]
	if not r then
		r = { ids = {}, order = {} }
		recent[player] = r
	end
	r.ids[requestId] = response
	table.insert(r.order, requestId)
	if #r.order > MAX_RECENT then
		r.ids[table.remove(r.order, 1)] = nil
	end
end

local function dispatch(remoteName, player, payload)
	if type(payload) ~= "table" or type(payload.action) ~= "string" then
		return { ok = false, error = "invalid", message = "Pedido inválido." }
	end
	local entry = handlers[remoteName][payload.action]
	if not entry then
		return { ok = false, error = "invalid", message = "Ação desconhecida." }
	end
	local profile = dataService.getProfile(player)
	if not profile then
		return { ok = false, error = "loading", message = "Carregando seus dados..." }
	end
	local requestId = payload.requestId
	if type(requestId) == "string" and #requestId <= 64 then
		local r = recent[player]
		if r and r.ids[requestId] then
			return r.ids[requestId]
		end
	else
		requestId = nil
	end
	if not RateLimiter.allow(player, entry.category) then
		return { ok = false, error = "rate", message = "Calma! Muitos pedidos seguidos." }
	end
	if busy[player] then
		return { ok = false, error = "busy", message = "Aguarde a ação anterior terminar." }
	end
	busy[player] = true
	local backup = ProfileSchema.deepCopy(profile)
	local ok, result = pcall(entry.fn, player, profile, payload)
	busy[player] = nil
	if not ok then
		warn("[MYSTERY MACHINE] erro em " .. remoteName .. "." .. payload.action .. ": " .. tostring(result))
		dataService.restore(player, backup)
		result = { ok = false, error = "server", message = "Algo deu errado. Nada foi alterado." }
	elseif type(result) ~= "table" then
		result = { ok = false, error = "server", message = "Resposta inválida." }
	end
	if result.ok then
		dataService.markDirty(player)
		for _, fn in ipairs(afterSuccess) do
			fn(player, result)
		end
	end
	if requestId then
		remember(player, requestId, result)
	end
	return result
end

function Remotes.init(playerDataService)
	dataService = playerDataService
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(Remotes.Functions) do
		local rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = folder
		handlers[name] = {}
		rf.OnServerInvoke = function(player, payload)
			return dispatch(name, player, payload)
		end
	end
	for _, name in ipairs(Remotes.Events) do
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = folder
	end
end

-- registra fn(player, profile, payload) -> resultado para remote/action
function Remotes.handle(remoteName, action, category, fn)
	handlers[remoteName][action] = { fn = fn, category = category }
end

function Remotes.onSuccess(fn)
	table.insert(afterSuccess, fn)
end

function Remotes.event(name)
	return folder:FindFirstChild(name)
end

function Remotes.notify(player, text, kind)
	Remotes.event("Notify"):FireClient(player, { text = text, kind = kind or "info" })
end

function Remotes.notifyAll(text, kind)
	Remotes.event("Notify"):FireAllClients({ text = text, kind = kind or "info" })
end

function Remotes.clear(player)
	recent[player] = nil
	busy[player] = nil
	RateLimiter.clear(player)
end

return Remotes
