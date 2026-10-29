-- EventService: anuncia os eventos de mutação (agenda fixa em EventConfig) e atualiza a placa da praça.
-- O efeito dos eventos é aplicado pela lógica compartilhada (Odds/Income) usando o horário do servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local EventConfig = require(Shared.Config.EventConfig)
local Format = require(Shared.Util.Format)

local PlayerDataService = require(script.Parent.PlayerDataService)
local MapService = require(script.Parent.MapService)
local BaseService = require(script.Parent.BaseService)

local EventService = {}

local lastEventKey = nil

function EventService.update(now)
	local ev = EventConfig.at(now)
	local key = ev and (ev.id .. ":" .. ev.startsAt) or nil
	if key ~= lastEventKey then
		lastEventKey = key
		if ev then
			BaseService.notifyAll("event", ev.icon .. " EVENTO: " .. ev.name .. "! " .. ev.description)
			workspace:SetAttribute("EventId", ev.id)
		else
			workspace:SetAttribute("EventId", nil)
		end
		-- todos recebem a fotografia nova (chances e bônus mudam com o evento)
		for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
			PlayerDataService.push(p)
		end
	end
	if MapService.eventLabel then
		if ev then
			MapService.eventLabel.Text = ev.icon .. " " .. ev.name .. "\n<font color='#FFD84A'>termina em " .. Format.duration(ev.endsAt - now) .. "</font>"
		else
			local n = EventConfig.nextEvent(now)
			MapService.eventLabel.Text = "Próximo evento\n" .. n.icon .. " " .. n.name .. "\n<font color='#9FD8FF'>em " .. Format.duration(n.startsAt - now) .. "</font>"
		end
	end
end

-- usado em testes/Studio: força um evento agora
function EventService.force(id, seconds)
	local now = PlayerDataService.now()
	local ev = EventConfig.force(id, now, seconds)
	EventService.update(now)
	return ev
end

function EventService.init() end

function EventService.start()
	task.spawn(function()
		while true do
			EventService.update(PlayerDataService.now())
			task.wait(1)
		end
	end)
end

return EventService
