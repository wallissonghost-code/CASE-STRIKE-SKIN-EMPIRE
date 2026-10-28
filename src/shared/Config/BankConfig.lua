-- BankConfig: renda passiva por skins depositadas.
-- O banco gera SOMENTE créditos virtuais do jogo. Nunca Robux ou dinheiro real.

local BankConfig = {}

-- Fórmula de renda (créditos por segundo) de uma skin:
--   renda = K * valor ^ EXPONENT * multiplicadorDaRaridade
--   limitada a MaxIncomePerSkin
-- EXPONENT < 1 dá retornos decrescentes: skins caras rendem mais, mas proporcionalmente menos.
BankConfig.K = 0.00025
BankConfig.Exponent = 0.82
BankConfig.MaxIncomePerSkin = 12 -- créditos/s
BankConfig.MinIncomePerSkin = 0.001

BankConfig.BaseSlots = 3
BankConfig.BaseStorage = 1500 -- créditos acumulados máximos antes do resgate
BankConfig.MaxOfflineSeconds = 8 * 3600 -- produção offline máxima: 8 horas

-- Melhorias com preços progressivos e limites definidos.
-- cost(level) = baseCost * growth ^ level (level = nível atual, começando em 0)
BankConfig.Upgrades = {
	slots = {
		id = "slots",
		displayName = "Vagas extras",
		description = "+1 vaga no banco",
		baseCost = 400,
		growth = 2.3,
		maxLevel = 9, -- até 12 vagas
		perLevel = 1,
		requiredLevel = function(level)
			return 1 + level * 2
		end,
	},
	efficiency = {
		id = "efficiency",
		displayName = "Eficiência",
		description = "+4% de renda (moderado)",
		baseCost = 1200,
		growth = 2.8,
		maxLevel = 5, -- até +20%
		perLevel = 0.04,
		requiredLevel = function(level)
			return 3 + level * 3
		end,
	},
	storage = {
		id = "storage",
		displayName = "Cofre maior",
		description = "+60% de capacidade de armazenamento",
		baseCost = 600,
		growth = 2.2,
		maxLevel = 8,
		perLevel = 0.6, -- multiplicativo: BaseStorage * (1 + 0.6) ^ nível
		requiredLevel = function(level)
			return 1 + level * 2
		end,
	},
	display = {
		id = "display",
		displayName = "Espaço de exposição",
		description = "+1 vaga de equipamento em exibição",
		baseCost = 2500,
		growth = 3.0,
		maxLevel = 3,
		perLevel = 1,
		requiredLevel = function(level)
			return 5 + level * 5
		end,
	},
}

BankConfig.UpgradeOrder = { "slots", "efficiency", "storage", "display" }

return BankConfig
