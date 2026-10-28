-- Store: última fotografia do perfil recebida do servidor (somente leitura no cliente).

local Signal = require(script.Parent.Signal)
local Net = require(script.Parent.Net)

local Store = {}

Store.view = nil
Store.receivedAt = 0 -- os.clock() quando a fotografia chegou
Store.changed = Signal.new()

local itemsByUid = {}

local function set(view)
	if type(view) ~= "table" then
		return
	end
	Store.view = view
	Store.receivedAt = os.clock()
	itemsByUid = {}
	for _, item in ipairs(view.items or {}) do
		itemsByUid[item.uid] = item
	end
	Store.changed:Fire(view)
end

function Store.item(uid)
	return itemsByUid[uid]
end

-- horário do servidor estimado (para contagens de tempo reais)
function Store.serverNow()
	if not Store.view then
		return 0
	end
	return Store.view.serverTime + (os.clock() - Store.receivedAt)
end

-- créditos pendentes do banco extrapolados para exibição (o valor real é do servidor)
function Store.bankPendingLive()
	local v = Store.view
	if not v then
		return 0
	end
	local b = v.bank
	local elapsed = math.min(os.clock() - Store.receivedAt, b.maxOfflineSeconds)
	return math.min(b.storageCap, b.pending + b.rate * elapsed)
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
