-- MissionService: resgate de missões diárias/semanais e de desafios de evento.
-- O progresso é atualizado pela lógica de cada operação (ProfileOps.emit); a virada de
-- dia/semana/evento é detectada pelo EventService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ProfileOps = require(Shared.Logic.ProfileOps)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local Validate = require(script.Parent.Parent.Core.Validate)
local PlayerDataService = require(script.Parent.PlayerDataService)

local MissionService = {}

function MissionService.init() end

function MissionService.start()
	Remotes.on("ClaimReward", "claimMission", "Progression", function(player, payload)
		if not Validate.id(payload.missionId, 32) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.claimMission(profile, ctx, payload.missionId)
		end, { important = true })
	end)

	Remotes.on("ClaimReward", "claimEventChallenge", "Progression", function(player, payload)
		if not Validate.id(payload.challengeId, 40) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.claimEventChallenge(profile, ctx, payload.challengeId)
		end, { important = true })
	end)
end

return MissionService
