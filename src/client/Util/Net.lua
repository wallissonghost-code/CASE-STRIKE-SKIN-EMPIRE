-- Chamadas ao servidor com requestId único (o servidor devolve a mesma resposta se o pedido
-- se repetir, sem cobrar de novo) e trava local por ação para evitar cliques duplos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Net = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local busy = {}

function Net.remote(name)
	return remotes:WaitForChild(name)
end

-- retorna { ok = true, ... } ou { ok = false, error, message }
function Net.call(remoteName, payload)
	local key = remoteName .. ":" .. tostring(payload.action)
	if busy[key] then
		return { ok = false, error = "busy", message = "Aguarde..." }
	end
	busy[key] = true
	payload.requestId = HttpService:GenerateGUID(false)
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
