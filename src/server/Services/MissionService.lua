-- Missões diárias (trocam todo dia UTC, resgate único por dia) e conquistas (resgate único).
-- O progresso é registrado pelas próprias operações (ProfileOps.track); aqui ficam os resgates
-- e o contador de tempo de jogo da missão gratuita "passear pelo parque".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileOps = require(Shared.Logic.ProfileOps)
local TimeUtil = require(Shared.Util.TimeUtil)
local Remotes = require(script.Parent.Parent.Core.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local MissionService = {}

MissionService.PlaytimeTick = 30

function MissionService.tickPlaytime()
	local now = TimeUtil.now()
	for _, player in ipairs(PlayerDataService.loadedPlayers()) do
		local profile = PlayerDataService.getProfile(player)
		local dayChanged = ProfileOps.ensureDaily(profile, now)
		if ProfileOps.addPlaytime(profile, MissionService.PlaytimeTick, now) or dayChanged then
			PlayerDataService.markDirty(player)
		end
	end
end

function MissionService.start()
	Remotes.handle("ProgressAction", "claimDaily", "progress", function(_, profile, payload)
		return ProfileOps.claimDaily(profile, payload.missionId, TimeUtil.now())
	end)
	Remotes.handle("ProgressAction", "claimAchievement", "progress", function(_, profile, payload)
		return ProfileOps.claimAchievement(profile, payload.achievementId)
	end)
	task.spawn(function()
		while true do
			task.wait(MissionService.PlaytimeTick)
			MissionService.tickPlaytime()
		end
	end)
end

return MissionService
