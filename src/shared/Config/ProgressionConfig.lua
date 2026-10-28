-- ProgressionConfig: níveis, XP, desbloqueios, recompensas de nível/diárias/coleção e renascimento.

local ProgressionConfig = {}

ProgressionConfig.MaxLevel = 100

-- XP necessário para ir do nível L para L+1 (curva gradual e configurável)
ProgressionConfig.XpBase = 100
ProgressionConfig.XpExponent = 1.45

function ProgressionConfig.xpForLevel(level)
	return math.floor(ProgressionConfig.XpBase * (level ^ ProgressionConfig.XpExponent) + 0.5)
end

-- Fontes repetitivas de XP têm limite diário (evita XP ilimitado por ação repetida).
-- Fontes únicas (descoberta, coleção, missão) não têm limite porque só ocorrem uma vez por item/período.
ProgressionConfig.DailyXpCaps = {
	open = 250,
	upgrade = 600,
	event = 400,
}

-- Títulos (cosméticos) e o que cada nível desbloqueia (exibição + regras reais).
ProgressionConfig.Titles = {
	novato = { id = "novato", displayName = "Colecionador Novato" },
	cacador = { id = "cacador", displayName = "Caçador de Skins" },
	curador = { id = "curador", displayName = "Curador" },
	magnata = { id = "magnata", displayName = "Magnata das Skins" },
	imperador = { id = "imperador", displayName = "Imperador do Arsenal" },
	renascido = { id = "renascido", displayName = "Renascido" },
	fenix = { id = "fenix", displayName = "Fênix do Império" },
	completista = { id = "completista", displayName = "Completista" },
}

-- Recompensas por nível (resgatáveis em Presentes, uma única vez cada).
ProgressionConfig.LevelRewards = {
	[2] = { credits = 100 },
	[3] = { credits = 150, freeCases = { tactical = 1 } },
	[5] = { credits = 300, materials = { scrap = 10, pigment = 2 }, title = "cacador" },
	[8] = { credits = 600, freeCases = { neon = 1 } },
	[10] = { credits = 1000, materials = { core = 1 }, title = "curador" },
	[15] = { credits = 2500, freeCases = { shadow = 1 } },
	[20] = { credits = 5000, materials = { core = 2 }, title = "magnata" },
	[25] = { credits = 8000, freeCases = { elite = 1 } },
	[30] = { credits = 12000, materials = { core = 3 }, title = "imperador" },
	[40] = { credits = 25000, freeCases = { imperial = 1 } },
	[50] = { credits = 50000, materials = { core = 5 } },
}

-- Recompensa diária (ciclo de 7 dias; reinicia se pular um dia). Dia = dia UTC do servidor.
ProgressionConfig.DailyRewards = {
	{ credits = 50 },
	{ credits = 75, materials = { scrap = 3 } },
	{ credits = 100 },
	{ credits = 125, materials = { pigment = 1 } },
	{ credits = 150, freeCases = { urban = 2 } },
	{ credits = 200, materials = { scrap = 6 } },
	{ credits = 300, freeCases = { tactical = 1 }, luck = "luck_daily" },
}

-- Recompensa por completar cada coleção (caixa).
ProgressionConfig.CollectionRewards = {
	urban = { credits = 400, xp = 300, materials = { core = 1 } },
	tactical = { credits = 1000, xp = 500, materials = { core = 1 } },
	neon = { credits = 2500, xp = 800, materials = { core = 2 } },
	shadow = { credits = 7000, xp = 1200, materials = { core = 2 } },
	elite = { credits = 18000, xp = 1800, materials = { core = 3 } },
	imperial = { credits = 60000, xp = 3000, materials = { core = 5 }, title = "completista" },
}

-- XP fixo por completar uma coleção já está em CollectionRewards; por descobrir skins: RarityConfig.discoverXp.

-- Renascimento (prestígio opcional)
ProgressionConfig.Rebirth = {
	MaxRebirths = 10,
	-- Requisitos por etapa (índice = próximo renascimento)
	requiredLevel = function(nextRebirth)
		return 20 + (nextRebirth - 1) * 5
	end,
	requiredNetWorth = function(nextRebirth)
		return math.floor(25000 * (2.5 ^ (nextRebirth - 1)))
	end,
	-- O que é mantido: skins de raridade >= KeepMinTier, skins favoritas, índice de descobertas,
	-- coleções concluídas, conquistas, títulos e o contador de renascimentos.
	KeepMinTier = 4, -- Épica ou superior
	KeepFavorites = true,
	-- O que é reiniciado: créditos (voltam ao inicial), nível e XP, créditos pendentes do banco,
	-- melhorias do banco e skins abaixo de Épica que não estejam favoritadas.
	-- Benefícios moderados e permanentes por renascimento:
	BankEfficiencyPerRebirth = 0.05, -- +5% de renda por renascimento
	BankEfficiencyMax = 0.30,
	LuckPerRebirth = 0.02, -- +2% de sorte (ver LuckConfig)
	LuckMax = 0.10,
	ExtraEquipSlotEvery = 2, -- +1 vaga de exposição a cada 2 renascimentos
	TitleFirst = "renascido",
	TitleFifth = "fenix",
	ConfirmPhrase = "RENASCER",
}

return ProgressionConfig
