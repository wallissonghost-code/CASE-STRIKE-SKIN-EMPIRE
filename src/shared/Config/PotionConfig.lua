-- PotionConfig: poções de bônus temporário. São obtidas GRÁTIS (presentes, missões, níveis,
-- conquistas) — nunca vendidas por Robux. Ativar acrescenta tempo ao bônus (até o limite).
-- Os efeitos aparecem no HUD com o tempo restante calculado pelo relógio do servidor.

local PotionConfig = {}

PotionConfig.Order = { "luck", "xp", "income" }

PotionConfig.Potions = {
	luck = {
		id = "luck",
		displayName = "Poção da Sorte",
		icon = "🍀",
		description = "+10% de sorte (chances finais sempre exibidas).",
		duration = 10 * 60,
		maxStack = 60 * 60, -- no máximo 1 h acumulada
		luck = 0.10,
	},
	xp = {
		id = "xp",
		displayName = "Poção de XP",
		icon = "📘",
		description = "XP em dobro.",
		duration = 10 * 60,
		maxStack = 60 * 60,
		xpMultiplier = 2,
	},
	income = {
		id = "income",
		displayName = "Poção de Renda",
		icon = "💰",
		description = "Renda do banco ×1,5 enquanto ativa (mesmo offline, até o fim do tempo).",
		duration = 15 * 60,
		maxStack = 90 * 60,
		incomeMultiplier = 1.5,
	},
}

return PotionConfig
