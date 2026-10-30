-- Missões diárias, conquistas (missões permanentes), recompensas de coleção e títulos.
--
-- Missões diárias: todo dia (UTC) cada jogador recebe 3 missões: 1 gratuita (não exige gastar
-- moedas) + 2 sorteadas pelo número do dia. Cada missão só pode ser resgatada uma vez por dia.
-- `event`: qual ação faz a missão avançar (ver ProfileOps.track).
--
-- Conquistas: resgatáveis uma única vez. `metric` é calculado a partir do perfil (ProfileOps.metric).

local MissionDefinitions = {}

MissionDefinitions.DailyFree = {
	{ id = "d_pickup", text = "Coletar 5 moedas perdidas no parque", event = "pickup", target = 5, coins = 70, xp = 35 },
	{ id = "d_play", text = "Passear 10 minutos pelo parque", event = "playtime", target = 600, coins = 90, xp = 40 },
}

MissionDefinitions.DailyPool = {
	{ id = "d_open3", text = "Abrir 3 máquinas", event = "open", target = 3, coins = 60, xp = 40 },
	{ id = "d_open8", text = "Abrir 8 máquinas", event = "open", target = 8, coins = 150, xp = 70 },
	{ id = "d_sell2", text = "Vender 2 objetos comuns", event = "sell_common", target = 2, coins = 50, xp = 30 },
	{ id = "d_discover", text = "Descobrir 1 objeto novo", event = "discover", target = 1, coins = 100, xp = 60, needsUndiscovered = true },
	{ id = "d_display", text = "Expor 1 objeto na vitrine", event = "display", target = 1, coins = 40, xp = 25 },
	{ id = "d_sell5", text = "Vender 5 objetos", event = "sell", target = 5, coins = 80, xp = 35 },
}

MissionDefinitions.DailyCount = 3

MissionDefinitions.Achievements = {
	{ id = "a_first", text = "Abrir a primeira máquina", metric = "opens", target = 1, coins = 50, xp = 30 },
	{ id = "a_open50", text = "Abrir 50 máquinas", metric = "opens", target = 50, coins = 400, xp = 150 },
	{ id = "a_open250", text = "Abrir 250 máquinas", metric = "opens", target = 250, coins = 2500, xp = 400 },
	{ id = "a_disc5", text = "Descobrir 5 objetos", metric = "discovered", target = 5, coins = 150, xp = 100 },
	{ id = "a_disc10", text = "Descobrir 10 objetos", metric = "discovered", target = 10, coins = 800, xp = 250 },
	{ id = "a_disc15", text = "Descobrir 15 objetos", metric = "discovered", target = 15, coins = 3000, xp = 500 },
	{ id = "a_set", text = "Completar uma parte da coleção", metric = "setsComplete", target = 1, coins = 300, xp = 150 },
	{ id = "a_lvl5", text = "Alcançar o nível 5", metric = "level", target = 5, coins = 200, xp = 0 },
	{ id = "a_lvl10", text = "Alcançar o nível 10", metric = "level", target = 10, coins = 600, xp = 0 },
	{ id = "a_lvl15", text = "Alcançar o nível 15", metric = "level", target = 15, coins = 1500, xp = 0 },
	{ id = "a_lvl30", text = "Alcançar o nível 30", metric = "level", target = 30, coins = 6000, xp = 0 },
	{ id = "a_sell25", text = "Vender 25 objetos", metric = "sold", target = 25, coins = 250, xp = 120 },
	{ id = "a_show3", text = "Expor 3 objetos ao mesmo tempo", metric = "displayed", target = 3, coins = 300, xp = 120 },
	{ id = "a_legend", text = "Conseguir um objeto Lendário", metric = "bestRank", target = 5, coins = 1000, xp = 300 },
	{ id = "a_secret", text = "Encontrar o objeto Secreto", metric = "bestRank", target = 6, coins = 5000, xp = 800, title = "secret_hunter" },
}

-- Partes da coleção: completar todos os objetos de uma máquina (ou todos os 20).
MissionDefinitions.CollectionSets = {
	{ id = "set_common", machine = "common", name = "Coleção Comum", coins = 150, xp = 150, title = "starter" },
	{ id = "set_neon", machine = "neon", name = "Coleção Neon", coins = 1200, xp = 400, title = "neon_king" },
	{ id = "set_golden", machine = "golden", name = "Coleção Dourada", coins = 5000, xp = 800, title = "golden_baron" },
	{ id = "set_mystery", machine = "mystery", name = "Coleção Misteriosa", coins = 15000, xp = 1500, title = "mystery_master" },
	{ id = "set_all", name = "Coleção Completa", coins = 25000, xp = 3000, title = "legend" },
}

-- Títulos cosméticos exibidos acima da cabeça do jogador
MissionDefinitions.Titles = {
	starter = { name = "Colecionador Iniciante", color = Color3.fromRGB(190, 200, 210) },
	neon_king = { name = "Rei do Neon", color = Color3.fromRGB(0, 255, 210) },
	golden_baron = { name = "Barão Dourado", color = Color3.fromRGB(255, 205, 60) },
	mystery_master = { name = "Mestre do Mistério", color = Color3.fromRGB(170, 90, 255) },
	legend = { name = "Lenda da Coleção", color = Color3.fromRGB(255, 120, 40) },
	secret_hunter = { name = "Caçador de Segredos", color = Color3.fromRGB(255, 60, 70) },
}

local function index(list)
	local out = {}
	for _, d in ipairs(list) do
		out[d.id] = d
	end
	return out
end

MissionDefinitions.DailyById = index(MissionDefinitions.DailyPool)
for _, d in ipairs(MissionDefinitions.DailyFree) do
	MissionDefinitions.DailyById[d.id] = d
end
MissionDefinitions.AchievementById = index(MissionDefinitions.Achievements)
MissionDefinitions.SetById = index(MissionDefinitions.CollectionSets)

return MissionDefinitions
