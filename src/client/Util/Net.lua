-- Net: chamadas ao servidor com requestId único (o servidor ignora repetições do mesmo pedido)
-- e trava local por ação para evitar cliques duplos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Net = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local busy = {} -- [remote .. action] = true

function Net.remote(name)
	return remotes:WaitForChild(name)
end

-- Retorna a resposta { ok, data } ou { ok = false, error, message }.
-- Se a mesma ação já estiver em andamento, retorna erro "busy" sem chamar o servidor.
function Net.call(remoteName, payload)
	local key = remoteName .. ":" .. tostring(payload.action)
	if busy[key] then
		return { ok = false, error = "busy", message = "Aguarde..." }
	end
	busy[key] = true
	payload.requestId = string.sub(HttpService:GenerateGUID(false), 1, 36)
	local okCall, response = pcall(function()
		return Net.remote(remoteName):InvokeServer(payload)
	end)
	busy[key] = nil
	if not okCall or type(response) ~= "table" then
		return { ok = false, error = "network", message = "Falha de conexão. Tente novamente." }
	end
	return response
end

function Net.on(eventName, fn)
	return Net.remote(eventName).OnClientEvent:Connect(fn)
end

return Net
