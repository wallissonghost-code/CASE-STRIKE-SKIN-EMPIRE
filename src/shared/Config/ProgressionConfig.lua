-- ProgressionConfig: níveis, XP, títulos, recompensas de nível/diárias/coleção e renascimento.

local ProgressionConfig = {}

ProgressionConfig.MaxLevel = 100

-- XP necessário para ir do nível L para L+1 (curva progressiva e configurável)
ProgressionConfig.XpBase = 100
ProgressionConfig.XpExponent = 1.45

function ProgressionConfig.xpForLevel(level)
	return math.floor(ProgressionConfig.XpBase * (level ^ ProgressionConfig.XpExponent) + 0.5)
end

-- Fontes repetitivas de XP têm limite diário (evita XP ilimitado por ação repetida).
-- Descobertas, coleções, missões e conquistas só ocorrem uma vez por item/período.
ProgressionConfig.DailyXpCaps = {
	open = 250,
	upgrade = 600,
	event = 400,
}

-- XP concedido ao desbloquear uma conquista
ProgressionConfig.AchievementXp = 120

-- Títulos. Os de nível são desbloqueados automaticamente ao alcançar o nível.
ProgressionConfig.Titles = {
	novato = { id = "novato", displayName = "Novato", level = 1 },
	colecionador = { id = "colecionador", displayName = "Colecionador", level = 5 },
	especialista = { id = "especialista", displayName = "Especialista", level = 15 },
	magnata = { id = "magnata", displayName = "Magnata", level = 30 },
	mestre = { id = "mestre", displayName = "Mestre", level = 50 },
	lendario = { id = "lendario", displayName = "Lendário", level = 75 },
	-- títulos de coleção, renascimento e evento
	renascido = { id = "renascido", displayName = "Renascido" },
	fenix = { id = "fenix", displayName = "Fênix do Império" },
	cacador_sombras = { id = "cacador_sombras", displayName = "Caçador de Sombras" },
	espirito_natal = { id = "espirito_natal", displayName = "Espírito do Natal" },
	recruta = { id = "recruta", displayName = "Recruta Graduado" },
	grafiteiro = { id = "grafiteiro", displayName = "Grafiteiro" },
	operador = { id = "operador", displayName = "Operador Tático" },
	arcade = { id = "arcade", displayName = "Rei do Fliperama" },
	eclipse = { id = "eclipse", displayName = "Filho do Eclipse" },
	cromado = { id = "cromado", displayName = "Cromado" },
	assombrado = { id = "assombrado", displayName = "Assombrado" },
	porcelana = { id = "porcelana", displayName = "Curador de Porcelana" },
	lapidador = { id = "lapidador", displayName = "Lapidador" },
	dinasta = { id = "dinasta", displayName = "Dinasta" },
	mitologo = { id = "mitologo", displayName = "Mitólogo" },
	cosmico = { id = "cosmico", displayName = "Ser Cósmico" },
}
ProgressionConfig.LevelTitleOrder = { "novato", "colecionador", "especialista", "magnata", "mestre", "lendario" }

-- Recompensas por nível (resgatáveis em Presentes, uma única vez cada).
ProgressionConfig.LevelRewards = {
	[2] = { credits = 200 },
	[3] = { credits = 300, freeCases = { tactical = 1 } },
	[5] = { credits = 500, materials = { scrap = 10, pigment = 2 }, potions = { xp = 1 } },
	[8] = { credits = 900, freeCases = { neon = 1 } },
	[10] = { credits = 1500, materials = { core = 1 }, potions = { luck = 2 } },
	[15] = { credits = 3000, freeCases = { chrome = 1 } },
	[20] = { credits = 6000, materials = { core = 2 }, potions = { income = 2 } },
	[25] = { credits = 9000, freeCases = { elite = 1 } },
	[30] = { credits = 15000, materials = { core = 3 } },
	[40] = { credits = 30000, freeCases = { diamond = 1 } },
	[50] = { credits = 60000, materials = { core = 5 } },
	[60] = { credits = 100000, freeCases = { royal = 1 } },
	[75] = { credits = 250000, freeCases = { mythic = 1 } },
	[90] = { credits = 500000, materials = { core = 10 } },
	[100] = { credits = 1000000, freeCases = { infinity = 1 } },
}

-- Recompensa diária (ciclo de 7 dias; reinicia se pular um dia). Dia = dia UTC do servidor.
ProgressionConfig.DailyRewards = {
	{ credits = 100 },
	{ credits = 150, materials = { scrap = 3 } },
	{ credits = 200, potions = { luck = 1 } },
	{ credits = 250, materials = { pigment = 1 } },
	{ credits = 300, freeCases = { urban = 2 } },
	{ credits = 400, materials = { scrap = 6 }, potions = { income = 1 } },
	{ credits = 600, freeCases = { tactical = 1 }, luck = "luck_daily" },
}

-- Recompensa por completar cada coleção: créditos/XP/materiais, título, moldura de coleção
-- (cosmetic "frame_<id>"), vitrine/decoração no showroom (cosmetic "showcase_<id>")
-- e a variante cosmética exclusiva da coleção (cosmetic "variant_<id>", aplicável na oficina sem custo).
local function col(credits, xp, core, title)
	return { credits = credits, xp = xp, materials = { core = core }, title = title }
end
ProgressionConfig.CollectionRewards = {
	starter = col(300, 200, 1, "recruta"),
	urban = col(700, 300, 1, "grafiteiro"),
	tactical = col(1800, 450, 1, "operador"),
	neon = col(3500, 650, 2, "arcade"),
	shadow = col(7000, 900, 2, "eclipse"),
	chrome = col(14000, 1200, 2, "cromado"),
	phantom = col(28000, 1600, 3, "assombrado"),
	elite = col(55000, 2100, 3, "porcelana"),
	diamond = col(110000, 2700, 4, "lapidador"),
	royal = col(260000, 3400, 4, "dinasta"),
	mythic = col(650000, 4200, 5, "mitologo"),
	infinity = col(2000000, 5000, 8, "cosmico"),
}
-- Cosméticos que toda coleção completa desbloqueia (além do título)
ProgressionConfig.CollectionCosmetics = { "frame", "showcase", "variant" }
ProgressionConfig.CosmeticNames = {
	frame = "Moldura da coleção",
	showcase = "Vitrine temática no showroom",
	variant = "Variante exclusiva da coleção",
}

-- Renascimento (prestígio opcional)
ProgressionConfig.Rebirth = {
	MaxRebirths = 10,
	requiredLevel = function(nextRebirth)
		return 25 + (nextRebirth - 1) * 5
	end,
	requiredNetWorth = function(nextRebirth)
		return math.floor(50000 * (2.5 ^ (nextRebirth - 1)))
	end,
	-- PRESERVADO: skins Raras ou superiores (nada raro é apagado), favoritas, índice,
	-- coleções, conquistas, títulos, cosméticos, materiais, caixas grátis e atributos.
	KeepMinTier = 3,
	KeepFavorites = true,
	-- REINICIADO: saldo (volta ao inicial), nível e XP, créditos pendentes do banco,
	-- melhorias do banco e skins Comuns/Incomuns não favoritadas.
	BankEfficiencyPerRebirth = 0.05,
	BankEfficiencyMax = 0.30,
	LuckPerRebirth = 0.02,
	LuckMax = 0.10,
	XpBonusPerRebirth = 0.05,
	XpBonusMax = 0.25,
	ExtraEquipSlotEvery = 2,
	ExtraBankSlotEvery = 2, -- +1 vaga de banco permanente a cada 2 renascimentos
	TitleFirst = "renascido",
	TitleFifth = "fenix",
	ConfirmPhrase = "RENASCER",
}

return ProgressionConfig
