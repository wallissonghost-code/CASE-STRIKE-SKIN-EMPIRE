-- EventConfig: eventos temporários com datas reais (UTC, controladas pelo relógio do servidor).
-- Nada de contagens regressivas falsas: a interface mostra o tempo real até o fim do evento,
-- calculado com o horário enviado pelo servidor.

local EventConfig = {}

EventConfig.Events = {
	{
		id = "ev_sombras_2026",
		name = "Festival das Sombras",
		description = "A coleção Shadow está em destaque. Desafios especiais e sorte extra de festival.",
		startsAt = 1792886400, -- 2026-10-25 00:00 UTC
		endsAt = 1794182400, -- 2026-11-09 00:00 UTC
		featuredCollection = "shadow",
		luckModifier = "luck_event",
		challenges = {
			{
				id = "evc_sombras_discover",
				description = "Descubra 3 skins da coleção Shadow",
				event = "discover",
				filter = { collection = "shadow" },
				target = 3,
				reward = { xp = 400, materials = { pigment = 4 }, title = "cacador" },
			},
			{
				id = "evc_sombras_open",
				description = "Abra 15 caixas Shadow",
				event = "open",
				filter = { caseId = "shadow" },
				target = 15,
				reward = { credits = 3000, xp = 300 },
			},
		},
	},
	{
		id = "ev_inverno_2026",
		name = "Exposição de Inverno",
		description = "Exposição de skins raras da coleção Elite e recompensas cosméticas de temporada.",
		startsAt = 1797033600, -- 2026-12-12 00:00 UTC
		endsAt = 1799193600, -- 2027-01-06 00:00 UTC
		featuredCollection = "elite",
		luckModifier = "luck_event",
		challenges = {
			{
				id = "evc_inverno_upgrade",
				description = "Conclua 4 receitas na oficina",
				event = "upgrade",
				target = 4,
				reward = { xp = 400, materials = { core = 2 } },
			},
			{
				id = "evc_inverno_epic",
				description = "Obtenha 2 skins Épicas ou superiores",
				event = "obtain",
				filter = { minTier = 4 },
				target = 2,
				reward = { credits = 5000, xp = 500 },
			},
		},
	},
}

-- Rotação semanal da coleção em destaque (sem evento ativo). Semana = semana UTC (segunda-feira).
EventConfig.WeeklyFeaturedRotation = { "urban", "tactical", "neon", "shadow", "elite", "imperial" }

function EventConfig.activeEvent(now)
	for _, ev in ipairs(EventConfig.Events) do
		if now >= ev.startsAt and now < ev.endsAt then
			return ev
		end
	end
	return nil
end

function EventConfig.nextEvent(now)
	local best = nil
	for _, ev in ipairs(EventConfig.Events) do
		if ev.startsAt > now and (best == nil or ev.startsAt < best.startsAt) then
			best = ev
		end
	end
	return best
end

EventConfig.ChallengeById = {}
for _, ev in ipairs(EventConfig.Events) do
	for _, c in ipairs(ev.challenges) do
		c.eventId = ev.id
		EventConfig.ChallengeById[c.id] = c
	end
end

return EventConfig
