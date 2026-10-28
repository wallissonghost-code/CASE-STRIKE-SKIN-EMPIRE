-- RewardService: presentes gratuitos (diário, por nível e por conquista).
-- Usa o relógio do servidor (UTC); o horário do dispositivo nunca é considerado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ProfileOps = require(Shared.Logic.ProfileOps)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local Validate = require(script.Parent.Parent.Core.Validate)
local PlayerDataService = require(script.Parent.PlayerDataService)

local RewardService = {}

function RewardService.init() end

function RewardService.start()
	Remotes.on("ProgressionAction", "claimDaily", "Progression", function(player)
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.claimDaily(profile, ctx)
		end, { important = true })
	end)

	Remotes.on("ProgressionAction", "claimLevelReward", "Progression", function(player, payload)
		if not Validate.int(payload.level, 1, 1000) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.claimLevelReward(profile, ctx, payload.level)
		end, { important = true })
	end)

	Remotes.on("ProgressionAction", "claimAchievement", "Progression", function(player, payload)
		if not Validate.id(payload.achievementId, 32) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.claimAchievement(profile, ctx, payload.achievementId)
		end, { important = true })
	end)
end

return RewardService
