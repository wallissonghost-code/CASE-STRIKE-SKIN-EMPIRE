-- Ações do inventário: vender, vender repetidos, favoritar, expor e retirar da vitrine.
-- O valor de venda vem sempre de ItemDefinitions (servidor); o cliente só manda id e quantidade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileOps = require(Shared.Logic.ProfileOps)
local TimeUtil = require(Shared.Util.TimeUtil)
local Remotes = require(script.Parent.Parent.Core.Remotes)

local InventoryService = {}

function InventoryService.start()
	Remotes.handle("InventoryAction", "sell", "inventory", function(_, profile, payload)
		return ProfileOps.sell(profile, payload.itemId, payload.amount or 1, payload.confirm == true, TimeUtil.now())
	end)
	Remotes.handle("InventoryAction", "sellDuplicates", "inventory", function(_, profile)
		return ProfileOps.sellDuplicates(profile, TimeUtil.now())
	end)
	Remotes.handle("InventoryAction", "favorite", "inventory", function(_, profile, payload)
		return ProfileOps.setFavorite(profile, payload.itemId, payload.value == true)
	end)
	Remotes.handle("InventoryAction", "display", "inventory", function(_, profile, payload)
		return ProfileOps.display(profile, payload.itemId, payload.slot, TimeUtil.now())
	end)
	Remotes.handle("InventoryAction", "undisplay", "inventory", function(_, profile, payload)
		return ProfileOps.undisplay(profile, payload.slot)
	end)
end

return InventoryService
