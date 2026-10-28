-- UpgradeService: oficina de melhorias cosméticas com resultado garantido.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ProfileOps = require(Shared.Logic.ProfileOps)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local Validate = require(script.Parent.Parent.Core.Validate)
local PlayerDataService = require(script.Parent.PlayerDataService)

local UpgradeService = {}

function UpgradeService.init() end

function UpgradeService.start()
	Remotes.on("UpgradeAction", "apply", "Upgrade", function(player, payload)
		if not Validate.id(payload.uid, 24) or not Validate.id(payload.recipeId, 24) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.applyUpgrade(profile, ctx, payload.uid, payload.recipeId)
		end, { important = true })
	end)
end

return UpgradeService
