-- AchievementDefinitions: conquistas permanentes. Desbloqueio automático pelo servidor;
-- a recompensa é resgatada uma única vez em Presentes.
-- stat: chave calculada em Logic/ProfileOps (statValue)

local AchievementDefinitions = {}

AchievementDefinitions.List = {
	{ id = "a_open1", name = "Primeiro Giro", description = "Abra sua primeira caixa", stat = "casesOpened", target = 1, reward = { credits = 50 } },
	{ id = "a_open100", name = "Mão Quente", description = "Abra 100 caixas", stat = "casesOpened", target = 100, reward = { credits = 600, materials = { scrap = 10 } } },
	{ id = "a_open1000", name = "Roleta Incansável", description = "Abra 1.000 caixas", stat = "casesOpened", target = 1000, reward = { credits = 8000, materials = { core = 2 } } },
	{ id = "a_unique10", name = "Catalogador", description = "Descubra 10 skins diferentes", stat = "uniqueDiscovered", target = 10, reward = { credits = 300 } },
	{ id = "a_unique30", name = "Arquivista", description = "Descubra 30 skins diferentes", stat = "uniqueDiscovered", target = 30, reward = { credits = 2500, materials = { pigment = 5 } } },
	{ id = "a_unique60", name = "Enciclopédia Viva", description = "Descubra as 60 skins", stat = "uniqueDiscovered", target = 60, reward = { credits = 50000, materials = { core = 5 } } },
	{ id = "a_col1", name = "Primeira Coleção", description = "Complete 1 coleção", stat = "collectionsCompleted", target = 1, reward = { credits = 500 } },
	{ id = "a_col6", name = "Meio Museu", description = "Complete 6 coleções", stat = "collectionsCompleted", target = 6, reward = { credits = 30000, materials = { core = 3 } } },
	{ id = "a_col12", name = "Museu Completo", description = "Complete as 12 coleções", stat = "collectionsCompleted", target = 12, reward = { credits = 500000, materials = { core = 10 } } },
	{ id = "a_income10", name = "Rentista", description = "Alcance 10 créditos/s de renda no banco", stat = "bankIncome", target = 10, reward = { credits = 5000 } },
	{ id = "a_worth10k", name = "Primeiros 10 mil", description = "Alcance 10.000 de patrimônio", stat = "netWorth", target = 10000, reward = { credits = 500 } },
	{ id = "a_worth1m", name = "Milionário de Skins", description = "Alcance 1.000.000 de patrimônio", stat = "netWorth", target = 1000000, reward = { credits = 20000, materials = { core = 3 } } },
	{ id = "a_level10", name = "Veterano", description = "Alcance o nível 10", stat = "level", target = 10, reward = { credits = 800 } },
	{ id = "a_upgrade10", name = "Artesão", description = "Conclua 10 melhorias na oficina", stat = "upgradesDone", target = 10, reward = { credits = 1500, materials = { pigment = 4 } } },
	{ id = "a_bank5k", name = "Juros Compostos", description = "Resgate 5.000 créditos do banco no total", stat = "bankClaimedTotal", target = 5000, reward = { credits = 1000 } },
	{ id = "a_rebirth1", name = "Renascer das Cinzas", description = "Renasça pela primeira vez", stat = "rebirths", target = 1, reward = { credits = 2000, materials = { core = 2 } } },
	{ id = "a_level50", name = "Mestre Colecionador", description = "Alcance o nível 50", stat = "level", target = 50, reward = { credits = 50000 } },
}

AchievementDefinitions.ById = {}
for _, a in ipairs(AchievementDefinitions.List) do
	AchievementDefinitions.ById[a.id] = a
end

return AchievementDefinitions
