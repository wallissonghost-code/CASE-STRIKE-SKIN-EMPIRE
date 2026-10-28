-- LuckConfig: modificadores de sorte. Todos transparentes:
-- o servidor recalcula os pesos e a interface mostra as probabilidades finais de cada skin.
-- Nenhum modificador é vendido por Robux.

local LuckConfig = {}

-- Sorte total máxima somando todas as fontes
LuckConfig.MaxTotalLuck = 0.25

-- Quanto a sorte amplifica cada raridade (multiplicador = 1 + sorte * escala)
-- Raridades sem escala (Comum/Incomum) não são amplificadas; após a normalização
-- a chance delas diminui na mesma proporção em que a das raras aumenta.
LuckConfig.TierScale = {
	[3] = 1.0, -- Rara
	[4] = 1.5, -- Épica
	[5] = 2.0, -- Lendária
	[6] = 2.5, -- Secreta
}

-- Definições de modificadores temporários
-- kind = "timed" (dura N segundos) | "uses" (vale para N aberturas)
LuckConfig.Modifiers = {
	luck_daily = {
		id = "luck_daily",
		displayName = "Bênção diária",
		source = "Recompensa diária (dia 7)",
		kind = "timed",
		duration = 15 * 60,
		luck = 0.05,
		maxStacks = 1,
	},
	luck_mission = {
		id = "luck_mission",
		displayName = "Amuleto de missão",
		source = "Missão semanal",
		kind = "uses",
		uses = 25,
		luck = 0.08,
		maxStacks = 1,
	},
	luck_event = {
		id = "luck_event",
		displayName = "Festival ativo",
		source = "Evento temporário",
		kind = "event", -- ativo apenas enquanto o evento estiver ativo (datas do servidor)
		luck = 0.03,
		maxStacks = 1,
	},
}

return LuckConfig
