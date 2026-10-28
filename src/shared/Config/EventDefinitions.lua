-- EventDefinitions: eventos temporários com datas reais (UTC), controladas pelo relógio do servidor.
-- Sem contagens regressivas falsas: a interface calcula o tempo real até o início/fim
-- usando o horário enviado pelo servidor. Para um novo evento, basta acrescentar uma entrada.
--
-- featuredCollection: coleção em destaque (missão semanal de destaque usa esta coleção)
-- luckModifier: bônus de sorte ativo durante o evento (LuckConfig)
-- challenges: desafios exclusivos com recompensas (resgatados em Missões)

local EventDefinitions = {}

local function utc(y, m, d)
	-- dias desde 1970-01-01 (algoritmo de Howard Hinnant), sem depender de os.time
	y = (m <= 2) and (y - 1) or y
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = math.floor((153 * mp + 2) / 5) + d - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return (era * 146097 + doe - 719468) * 86400
end
EventDefinitions.utc = utc

EventDefinitions.Events = {
	{
		id = "ev_halloween_2026",
		name = "Halloween das Sombras",
		description = "Coleções Eclipse e Assombro em destaque, desafios assustadores e sorte extra.",
		startsAt = utc(2026, 10, 25),
		endsAt = utc(2026, 11, 9),
		featuredCollection = "shadow",
		luckModifier = "luck_event",
		challenges = {
			{ id = "evc_hw_discover", description = "Descubra 3 skins das coleções Eclipse ou Assombro", event = "discover", filter = { collections = { "shadow", "phantom" } }, target = 3, reward = { xp = 500, materials = { pigment = 4 }, title = "cacador_sombras" } },
			{ id = "evc_hw_open", description = "Abra 15 caixas Shadow", event = "open", filter = { caseId = "shadow" }, target = 15, reward = { credits = 4000, xp = 300 } },
		},
	},
	{
		id = "ev_neon_2026",
		name = "Semana Neon",
		description = "A Coleção Fliperama brilha mais: desafios de coleção e sorte extra.",
		startsAt = utc(2026, 11, 23),
		endsAt = utc(2026, 11, 30),
		featuredCollection = "neon",
		luckModifier = "luck_event",
		challenges = {
			{ id = "evc_neon_open", description = "Abra 20 caixas Neon", event = "open", filter = { caseId = "neon" }, target = 20, reward = { credits = 3000, freeCases = { neon = 2 } } },
			{ id = "evc_neon_upgrade", description = "Conclua 3 melhorias na oficina", event = "upgrade", target = 3, reward = { xp = 350, materials = { pigment = 5 } } },
		},
	},
	{
		id = "ev_natal_2026",
		name = "Natal do Império",
		description = "Exposição de inverno da Coleção Porcelana e presentes de temporada.",
		startsAt = utc(2026, 12, 12),
		endsAt = utc(2027, 1, 6),
		featuredCollection = "elite",
		luckModifier = "luck_event",
		challenges = {
			{ id = "evc_natal_epic", description = "Obtenha 2 skins Épicas ou superiores", event = "obtain", filter = { minTier = 4 }, target = 2, reward = { credits = 8000, xp = 500, title = "espirito_natal" } },
			{ id = "evc_natal_bank", description = "Resgate o banco 10 vezes", event = "bankClaim", target = 10, reward = { xp = 400, materials = { core = 2 } } },
		},
	},
	{
		id = "ev_aniversario_2027",
		name = "Aniversário do CASE STRIKE",
		description = "Um ano de império: coleção Cosmos em destaque e desafios comemorativos.",
		startsAt = utc(2027, 3, 1),
		endsAt = utc(2027, 3, 15),
		featuredCollection = "infinity",
		luckModifier = "luck_event",
		challenges = {
			{ id = "evc_aniv_discover", description = "Descubra 5 skins inéditas", event = "discover", target = 5, reward = { credits = 10000, xp = 600 } },
			{ id = "evc_aniv_level", description = "Suba 2 níveis", event = "levelUp", target = 2, reward = { xp = 400, materials = { core = 3 } } },
		},
	},
}

-- Rotação semanal da coleção em destaque quando não há evento (semana UTC, segunda-feira)
EventDefinitions.WeeklyFeaturedRotation = { "starter", "urban", "tactical", "neon", "shadow", "chrome", "phantom", "elite", "diamond", "royal", "mythic", "infinity" }

function EventDefinitions.activeEvent(now)
	for _, ev in ipairs(EventDefinitions.Events) do
		if now >= ev.startsAt and now < ev.endsAt then
			return ev
		end
	end
	return nil
end

function EventDefinitions.nextEvent(now)
	local best = nil
	for _, ev in ipairs(EventDefinitions.Events) do
		if ev.startsAt > now and (best == nil or ev.startsAt < best.startsAt) then
			best = ev
		end
	end
	return best
end

EventDefinitions.ChallengeById = {}
for _, ev in ipairs(EventDefinitions.Events) do
	for _, c in ipairs(ev.challenges) do
		c.eventId = ev.id
		EventDefinitions.ChallengeById[c.id] = c
	end
end

return EventDefinitions
