-- ProgressConfig: missões diárias, presentes diários e marcos do índice.
-- Recompensas em moedas podem escalar com a renda do jogador:
--   coins = max(coins, rendaPorSegundo × 60 × incomeMinutes)
-- assim elas continuam valendo a pena no começo e no fim do jogo.

local ProgressConfig = {}

-- eventos de progresso emitidos pela lógica:
-- conveyorBuy, hatch, collect (quantidade = moedas), discover, sell, steal, defend, shield, upgrade, mutant
ProgressConfig.DailyMissionCount = 3
ProgressConfig.Missions = {
	{ id = "m_conveyor3", description = "Compre 3 criaturas na esteira", event = "conveyorBuy", target = 3, reward = { coins = 300, incomeMinutes = 4 } },
	{ id = "m_hatch3", description = "Abra 3 ovos", event = "hatch", target = 3, reward = { coins = 400, incomeMinutes = 5, potions = { sorte = 1 } } },
	{ id = "m_collect", description = "Colete 2.000 moedas na sua base", event = "collect", target = 2000, reward = { coins = 300, incomeMinutes = 3 } },
	{ id = "m_discover2", description = "Descubra 2 combinações novas no índice", event = "discover", target = 2, reward = { coins = 500, incomeMinutes = 5 } },
	{ id = "m_sell3", description = "Venda 3 criaturas", event = "sell", target = 3, reward = { coins = 200, incomeMinutes = 3 } },
	{ id = "m_steal1", description = "Roube 1 criatura e leve para sua base", event = "steal", target = 1, reward = { coins = 600, incomeMinutes = 6, potions = { velocidade = 1 } } },
	{ id = "m_defend1", description = "Pegue um ladrão na sua base", event = "defend", target = 1, reward = { coins = 600, incomeMinutes = 6, potions = { renda = 1 } } },
	{ id = "m_shield2", description = "Ative o escudo da base 2 vezes", event = "shield", target = 2, reward = { coins = 250, incomeMinutes = 3 } },
	{ id = "m_upgrade1", description = "Compre 1 melhoria da base", event = "upgrade", target = 1, reward = { coins = 400, incomeMinutes = 4 } },
	{ id = "m_mutant1", description = "Consiga 1 criatura mutante (não normal)", event = "mutant", target = 1, reward = { coins = 500, incomeMinutes = 5, potions = { sorte = 1 } } },
}
ProgressConfig.MissionById = {}
for _, m in ipairs(ProgressConfig.Missions) do
	ProgressConfig.MissionById[m.id] = m
end

-- presentes diários (sequência de 7 dias; perder um dia recomeça)
ProgressConfig.DailyGifts = {
	{ coins = 300, incomeMinutes = 5 },
	{ coins = 500, incomeMinutes = 8, potions = { velocidade = 1 } },
	{ coins = 800, incomeMinutes = 10, potions = { sorte = 1 } },
	{ coins = 1200, incomeMinutes = 12 },
	{ coins = 1800, incomeMinutes = 15, potions = { renda = 1 } },
	{ coins = 2500, incomeMinutes = 20, potions = { sorte = 1, velocidade = 1 } },
	{ coins = 5000, incomeMinutes = 30, potions = { sorte = 2, renda = 2 } },
}

-- marcos do índice: quantidade de combinações espécie × mutação descobertas
ProgressConfig.IndexMilestones = {
	{ id = "idx5", count = 5, reward = { coins = 500, potions = { sorte = 1 } } },
	{ id = "idx10", count = 10, reward = { coins = 2000, incomeMinutes = 10 } },
	{ id = "idx20", count = 20, reward = { coins = 8000, incomeMinutes = 20, potions = { sorte = 2 } } },
	{ id = "idx35", count = 35, reward = { coins = 40000, incomeMinutes = 30, potions = { renda = 2 } } },
	{ id = "idx50", count = 50, reward = { coins = 200000, incomeMinutes = 45, potions = { sorte = 3 } } },
	{ id = "idx70", count = 70, reward = { coins = 1000000, incomeMinutes = 60, potions = { sorte = 3, renda = 3 } } },
	{ id = "idx96", count = 96, reward = { coins = 10000000, incomeMinutes = 120, potions = { sorte = 5, renda = 5, velocidade = 5 } } },
}
ProgressConfig.MilestoneById = {}
for _, m in ipairs(ProgressConfig.IndexMilestones) do
	ProgressConfig.MilestoneById[m.id] = m
end

return ProgressConfig
