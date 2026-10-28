-- EventService: controla eventos temporários pelo relógio do servidor (EventDefinitions).
-- Detecta a virada de dia/semana e o início/fim de eventos, atualiza as missões de todos
-- os jogadores conectados e avisa o servidor quando um evento começa ou termina.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ProfileOps = require(Shared.Logic.ProfileOps)
local TimeUtil = require(Shared.Util.TimeUtil)
local EventDefinitions = require(Shared.Config.EventDefinitions)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local EventService = {}

local CHECK_INTERVAL = 30

local function now()
	return DateTime.now().UnixTimestamp
end

function EventService.current()
	return EventDefinitions.activeEvent(now())
end

function EventService.init() end

function EventService.start()
	task.spawn(function()
		local lastDay = TimeUtil.dayIndex(now())
		local lastWeek = TimeUtil.weekIndex(now())
		local ev = EventDefinitions.activeEvent(now())
		local lastEvent = ev and ev.id or ""
		while true do
			task.wait(CHECK_INTERVAL)
			local t = now()
			local day, week = TimeUtil.dayIndex(t), TimeUtil.weekIndex(t)
			local cur = EventDefinitions.activeEvent(t)
			local curId = cur and cur.id or ""
			if day ~= lastDay or week ~= lastWeek or curId ~= lastEvent then
				if curId ~= lastEvent then
					Remotes.event("CaseOpenResult"):FireAllClients({
						kind = "event",
						started = cur ~= nil,
						name = cur and cur.name or nil,
					})
				end
				lastDay, lastWeek, lastEvent = day, week, curId
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

return EventService
