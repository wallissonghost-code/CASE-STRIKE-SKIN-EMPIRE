-- Remotes: cria os remotes e despacha as ações recebidas para os serviços.
-- Toda chamada passa por: validação do formato, limite de frequência, deduplicação
-- por requestId (pedidos repetidos recebem a mesma resposta sem reexecutar) e pcall.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteNames = require(ReplicatedStorage.Shared.Net.RemoteNames)
local RateLimiter = require(script.Parent.RateLimiter)
local Validate = require(script.Parent.Validate)

local Remotes = {}

local folder
local handlers = {} -- [functionName][action] = { category, fn }
local recentRequests = {} -- [player] = { order = {}, responses = {} }
local MAX_RECENT = 40

function Remotes.init()
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in ipairs(RemoteNames.Functions) do
		local rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = folder
		handlers[name] = {}
		rf.OnServerInvoke = function(player, payload)
			return Remotes._dispatch(name, player, payload)
		end
	end
	for _, name in ipairs(RemoteNames.Events) do
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

function Remotes.event(name)
	return folder:FindFirstChild(name)
end

-- Registra o tratador de uma ação.
function Remotes.on(functionName, action, category, fn)
	assert(handlers[functionName], "remote desconhecido: " .. functionName)
	handlers[functionName][action] = { category = category, fn = fn }
end

function Remotes.fail(code, message)
	return { ok = false, error = code, message = message }
end

local function remember(player, requestId, response)
	local r = recentRequests[player]
	if not r then
		r = { order = {}, responses = {} }
		recentRequests[player] = r
	end
	r.responses[requestId] = response
	table.insert(r.order, requestId)
	if #r.order > MAX_RECENT then
		local old = table.remove(r.order, 1)
		r.responses[old] = nil
	end
end

function Remotes._dispatch(functionName, player, payload)
	if type(payload) ~= "table" or not Validate.id(payload.action, 32) then
		return Remotes.fail("invalid_request", "Pedido inválido.")
	end
	local h = handlers[functionName][payload.action]
	if not h then
		return Remotes.fail("invalid_request", "Ação desconhecida.")
	end
	local requestId = payload.requestId
	if requestId ~= nil then
		if not Validate.id(requestId, 40) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		local r = recentRequests[player]
		if r and r.responses[requestId] then
			return r.responses[requestId] -- pedido repetido: não executa de novo
		end
	end
	if not RateLimiter.allow(player, h.category) then
		return Remotes.fail("rate_limited", "Calma! Muitas ações em sequência.")
	end
	local ok, result = pcall(h.fn, player, payload)
	if not ok then
		warn("[Remotes] erro em " .. functionName .. "/" .. payload.action .. ": " .. tostring(result))
		return Remotes.fail("server_error", "Erro no servidor. Nada foi alterado; tente novamente.")
	end
	if type(result) ~= "table" then
		result = Remotes.fail("server_error", "Resposta inválida.")
	end
	if requestId ~= nil then
		remember(player, requestId, result)
	end
	return result
end

function Remotes.clearPlayer(player)
	recentRequests[player] = nil
	RateLimiter.clear(player)
end

return Remotes
