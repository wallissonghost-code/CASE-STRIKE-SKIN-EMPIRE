-- Loja de melhorias. Preço e efeito vêm de UpgradeConfig no servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileOps = require(Shared.Logic.ProfileOps)
local Remotes = require(script.Parent.Parent.Core.Remotes)

local UpgradeService = {}

function UpgradeService.start()
	Remotes.handle("UpgradeAction", "buy", "upgrade", function(_, profile, payload)
		return ProfileOps.buyUpgrade(profile, payload.upgradeId)
	end)
end

return UpgradeService
