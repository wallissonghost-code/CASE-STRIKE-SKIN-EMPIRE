-- MissionDefinitions: missões diárias e semanais. Nenhuma exige Robux.
-- event: nome do evento de progresso emitido pela lógica (ver Logic/ProfileOps).
-- filter: condição opcional sobre o payload do evento.

local MissionDefinitions = {}

MissionDefinitions.DailyCount = 3
MissionDefinitions.WeeklyCount = 3

MissionDefinitions.Daily = {
	{
		id = "d_discover2",
		description = "Descubra 2 skins inéditas",
		event = "discover",
		target = 2,
		reward = { credits = 120, xp = 60 },
	},
	{
		id = "d_sell3common",
		description = "Venda 3 itens comuns",
		event = "sell",
		filter = { rarity = "Common" },
		target = 3,
		reward = { credits = 60, xp = 40, materials = { scrap = 4 } },
	},
	{
		id = "d_deposit1",
		description = "Deposite 1 skin no banco",
		event = "deposit",
		target = 1,
		reward = { credits = 80, xp = 40 },
	},
	{
		id = "d_upgrade1",
		description = "Conclua 1 receita da oficina",
		event = "upgrade",
		target = 1,
		reward = { xp = 80, materials = { pigment = 2 } },
	},
	{
		id = "d_bankclaim2",
		description = "Resgate créditos do banco 2 vezes",
		event = "bankClaim",
		target = 2,
		reward = { credits = 100, xp = 40 },
	},
	{
		id = "d_open10",
		description = "Abra 10 caixas",
		event = "open",
		target = 10,
		reward = { xp = 70, freeCases = { urban = 1 } },
	},
	{
		id = "d_rare1",
		description = "Obtenha 1 skin Rara ou superior",
		event = "obtain",
		filter = { minTier = 3 },
		target = 1,
		reward = { xp = 60, materials = { scrap = 6, pigment = 1 } },
	},
	{
		id = "d_equip1",
		description = "Equipe uma skin para exibição",
		event = "equip",
		target = 1,
		reward = { credits = 40, xp = 25 },
	},
}

MissionDefinitions.Weekly = {
	{
		id = "w_discover10",
		description = "Descubra 10 skins inéditas",
		event = "discover",
		target = 10,
		reward = { credits = 1500, xp = 500, materials = { core = 1 } },
	},
	{
		id = "w_upgrade5",
		description = "Conclua 5 receitas da oficina",
		event = "upgrade",
		target = 5,
		reward = { xp = 400, materials = { pigment = 6, core = 1 } },
	},
	{
		id = "w_open60",
		description = "Abra 60 caixas",
		event = "open",
		target = 60,
		reward = { xp = 350, freeCases = { tactical = 2 } },
	},
	{
		id = "w_bank20",
		description = "Resgate créditos do banco 20 vezes",
		event = "bankClaim",
		target = 20,
		reward = { credits = 1200, xp = 300 },
	},
	{
		id = "w_featured3",
		description = "Descubra 3 skins da coleção em destaque",
		event = "discoverFeatured",
		target = 3,
		reward = { xp = 450, luck = "luck_mission" },
	},
	{
		id = "w_sell25",
		description = "Venda 25 skins",
		event = "sell",
		target = 25,
		reward = { credits = 800, xp = 250, materials = { scrap = 20 } },
	},
}

MissionDefinitions.ById = {}
for _, m in ipairs(MissionDefinitions.Daily) do
	m.period = "daily"
	MissionDefinitions.ById[m.id] = m
end
for _, m in ipairs(MissionDefinitions.Weekly) do
	m.period = "weekly"
	MissionDefinitions.ById[m.id] = m
end

-- Seleção determinística por período: todos os jogadores recebem as mesmas missões no mesmo dia/semana.
local function pick(pool, count, seed)
	local indices = {}
	for i = 1, #pool do
		indices[i] = i
	end
	-- embaralhamento determinístico (gerador Park-Miller; cabe com folga em double)
	local state = (math.floor(seed) % 2147483646) + 1
	for i = #indices, 2, -1 do
		state = (state * 16807) % 2147483647
		local j = (state % i) + 1
		indices[i], indices[j] = indices[j], indices[i]
	end
	local out = {}
	for i = 1, math.min(count, #indices) do
		table.insert(out, pool[indices[i]].id)
	end
	return out
end

function MissionDefinitions.dailyFor(dayIndex)
	return pick(MissionDefinitions.Daily, MissionDefinitions.DailyCount, dayIndex)
end

function MissionDefinitions.weeklyFor(weekIndex)
	return pick(MissionDefinitions.Weekly, MissionDefinitions.WeeklyCount, weekIndex + 7919)
end

return MissionDefinitions
