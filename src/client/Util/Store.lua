-- Estado do cliente: última fotografia do perfil enviada pelo servidor e o cache de rankings.
-- O cliente nunca altera estes dados por conta própria; só exibe.

local Signal = require(script.Parent.Signal)

local Store = {}

Store.view = nil
Store.leaderboard = nil
Store.changed = Signal.new()
Store.leaderboardChanged = Signal.new()

function Store.set(view)
	Store.view = view
	Store.changed:Fire(view)
end

function Store.setLeaderboard(data)
	Store.leaderboard = data
	Store.leaderboardChanged:Fire(data)
end

function Store.setting(key)
	local v = Store.view
	if v and v.settings then
		return v.settings[key]
	end
	return nil
end

return Store
