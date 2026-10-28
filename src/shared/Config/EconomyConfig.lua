-- EconomyConfig: parâmetros gerais da economia. Todos configuráveis.
-- Apenas moeda virtual obtida no jogo ("créditos"). Nada aqui converte em Robux ou dinheiro real.

local EconomyConfig = {}

EconomyConfig.StartingCredits = 500
EconomyConfig.MaxCredits = 1e12 -- teto de segurança contra overflow/exploits

-- Venda ao sistema: fração do valor da skin.
EconomyConfig.SellRate = 1.0

-- Materiais recebidos ao vender (por raridade). Usados na oficina.
EconomyConfig.SellMaterials = {
	Common = { scrap = 1 },
	Uncommon = { scrap = 2 },
	Rare = { scrap = 4, pigment = 1 },
	Epic = { scrap = 8, pigment = 2 },
	Legendary = { scrap = 15, pigment = 4, core = 1 },
	Secret = { scrap = 25, pigment = 6, core = 2 },
}

EconomyConfig.Materials = {
	scrap = { id = "scrap", displayName = "Sucata" },
	pigment = { id = "pigment", displayName = "Pigmento" },
	core = { id = "core", displayName = "Núcleo Polido" },
}

-- Confirmação extra: vender skins a partir desta raridade exige confirmação explícita
-- (Lendária e Secreta). A partir de RareWarnTier a interface mostra um aviso adicional.
EconomyConfig.ValuableConfirmTier = 5
EconomyConfig.RareWarnTier = 3

-- Showroom: skins escolhidas para exposição (cosmético, sem vantagem econômica)
EconomyConfig.ShowcaseSlots = 6

-- Inventário
EconomyConfig.InventoryCapacity = 500
EconomyConfig.BaseEquipSlots = 3
EconomyConfig.MaxEquipSlots = 8

-- Abertura
EconomyConfig.Opening = {
	NormalSpinSeconds = 5.5,
	FastSpinSeconds = 1.6,
	MultiSpinSeconds = 3.0,
	-- acima desta quantidade não há faixas animadas: só a grade de prêmios (desempenho no celular)
	MaxAnimatedStrips = 10,
	-- intervalo mínimo entre aberturas (servidor), por modo
	MinIntervalNormal = 1.0,
	MinIntervalFast = 0.9,
	-- abertura automática
	AutoMaxOpensPerSession = 150, -- depois disso precisa reativar
	AutoMaxSessionSeconds = 20 * 60, -- 20 minutos
	AutoMinInterval = 1.5,
	-- XP por abertura (limitado diariamente em ProgressionConfig)
	XpPerOpen = 2,
}

-- Histórico de transações mantido no perfil (anel)
EconomyConfig.TransactionLogSize = 60

-- Limites de frequência (tokens por janela) por categoria de ação
EconomyConfig.RateLimits = {
	CaseOpen = { capacity = 4, refillPerSecond = 1.2 },
	Inventory = { capacity = 12, refillPerSecond = 6 },
	Bank = { capacity = 8, refillPerSecond = 4 },
	Upgrade = { capacity = 6, refillPerSecond = 2 },
	Progression = { capacity = 8, refillPerSecond = 3 },
	Data = { capacity = 5, refillPerSecond = 1 },
	Leaderboard = { capacity = 3, refillPerSecond = 0.2 },
}

return EconomyConfig
