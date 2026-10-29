-- Store: última fotografia do perfil recebida do servidor (somente leitura no cliente).

local Signal = require(script.Parent.Signal)
local Net = require(script.Parent.Net)

local Store = {}

Store.view = nil
Store.receivedAt = 0 -- os.clock() quando a fotografia chegou
Store.changed = Signal.new()

local function set(view)
	if type(view) ~= "table" then
		return
	end
	Store.view = view
	Store.receivedAt = os.clock()
	Store.changed:Fire(view)
end

function Store.creature(uid)
	for _, c in ipairs(Store.view and Store.view.creatures or {}) do
		if c.uid == uid then
			return c
		end
	end
	return nil
end

-- horário do servidor estimado (para contagens de tempo reais)
function Store.serverNow()
	if not Store.view then
		return 0
	end
	return Store.view.serverTime + (os.clock() - Store.receivedAt)
end

-- moedas guardadas na base, estimadas para exibição (o valor real é sempre do servidor)
function Store.pendingLive()
	local v = Store.view
	if not v then
		return 0
	end
	local elapsed = os.clock() - Store.receivedAt
	local total = 0
	for _, c in ipairs(v.creatures) do
		total = total + math.min(c.cap, c.pending + c.rate * (v.boost or 1) * elapsed)
	end
	return total
end

function Store.init()
	Net.on("DataUpdated", set)
	task.spawn(function()
		while not Store.view do
			local res = Net.call("RequestData", { action = "get" })
			if res.ok then
				set(res.data)
			else
				task.wait(1.5)
			end
		end
	end)
end

return Store
