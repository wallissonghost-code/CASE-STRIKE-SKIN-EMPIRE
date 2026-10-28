-- MissionService: missões diárias/semanais e desafios de evento.
-- O progresso é atualizado pela lógica de cada operação (ProfileOps.emit).
-- Este serviço trata os resgates e detecta a virada do dia/semana para atualizar os clientes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ProfileOps = require(Shared.Logic.ProfileOps)
local TimeUtil = require(Shared.Util.TimeUtil)
local EventConfig = require(Shared.Config.EventConfig)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local Validate = require(script.Parent.Parent.Core.Validate)
local PlayerDataService = require(script.Parent.PlayerDataService)

local MissionService = {}

function MissionService.init() end

function MissionService.start()
	Remotes.on("ProgressionAction", "claimMission", "Progression", function(player, payload)
		if not Validate.id(payload.missionId, 32) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.claimMission(profile, ctx, payload.missionId)
		end, { important = true })
	end)

	Remotes.on("ProgressionAction", "claimEventChallenge", "Progression", function(player, payload)
		if not Validate.id(payload.challengeId, 40) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.claimEventChallenge(profile, ctx, payload.challengeId)
		end, { important = true })
	end)

	-- virada de dia/semana ou início/fim de evento: atualiza todos os jogadores
	task.spawn(function()
		local function periodKey()
			local now = DateTime.now().UnixTimestamp
			local ev = EventConfig.activeEvent(now)
			return TimeUtil.dayIndex(now) .. ":" .. TimeUtil.weekIndex(now) .. ":" .. (ev and ev.id or "")
		end
		local last = periodKey()
		while true do
			task.wait(30)
			local key = periodKey()
			if key ~= last then
				last = key
				for _, player in ipairs(Players:GetPlayers()) do
					if PlayerDataService.isLoaded(player) then
						PlayerDataService.run(player, function(profile, ctx)
							ProfileOps.refreshPeriods(profile, ctx.now)
							return true, {}
						end)
					end
				end
			end
		end
	end)
end

return MissionService
