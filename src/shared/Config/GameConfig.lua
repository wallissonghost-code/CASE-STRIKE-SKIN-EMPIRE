-- GameConfig: TODO o conteúdo e o balanceamento do MUTANT FACTORY ficam aqui.
-- Servidor e cliente leem o mesmo arquivo; a interface nunca tem números fixos.
-- Moeda única: Moedas (gratuita, ganha no jogo). Nada aqui é vendido por Robux.

local GameConfig = {}

GameConfig.StartingCoins = 300
GameConfig.MaxCoins = 1e15
GameConfig.SellRate = 0.5 -- vender devolve 50% do valor da criatura
GameConfig.ValuableConfirmTier = 5 -- vender Lendária ou Mítica exige confirmação

---------------------------------------------------------------------------
-- raridades
---------------------------------------------------------------------------
GameConfig.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
GameConfig.Rarities = {
	Common = { id = "Common", tier = 1, displayName = "Comum", color = { 170, 178, 190 } },
	Uncommon = { id = "Uncommon", tier = 2, displayName = "Incomum", color = { 80, 210, 110 } },
	Rare = { id = "Rare", tier = 3, displayName = "Rara", color = { 70, 150, 255 } },
	Epic = { id = "Epic", tier = 4, displayName = "Épica", color = { 175, 90, 250 } },
	Legendary = { id = "Legendary", tier = 5, displayName = "Lendária", color = { 255, 190, 50 } },
	Mythic = { id = "Mythic", tier = 6, displayName = "Mítica", color = { 255, 70, 95 } },
}

---------------------------------------------------------------------------
-- espécies (modelos feitos de peças no próprio jogo; nenhum asset externo)
-- shape: blob, spikes, drop, tentacles, ghost, mushroom, eye, dragon, cyclops, octopus, crown, phoenix, titan, core
---------------------------------------------------------------------------
GameConfig.Species = {
	{ id = "gosminha", name = "Gosminha", rarity = "Common", income = 1, price = 25, shape = "blob", color = { 90, 220, 110 } },
	{ id = "bolhudo", name = "Bolhudo", rarity = "Common", income = 2, price = 55, shape = "blob", color = { 80, 180, 255 } },
	{ id = "lodinho", name = "Lodinho", rarity = "Common", income = 3, price = 90, shape = "drop", color = { 140, 120, 80 } },
	{ id = "espinhoso", name = "Espinhoso", rarity = "Uncommon", income = 7, price = 280, shape = "spikes", color = { 255, 150, 60 } },
	{ id = "pingo_acido", name = "Pingo Ácido", rarity = "Uncommon", income = 10, price = 420, shape = "drop", color = { 190, 255, 60 } },
	{ id = "tentaclinho", name = "Tentaclinho", rarity = "Uncommon", income = 13, price = 560, shape = "tentacles", color = { 255, 110, 170 } },
	{ id = "fantasminha", name = "Fantasminha", rarity = "Rare", income = 30, price = 1800, shape = "ghost", color = { 220, 230, 255 } },
	{ id = "cogumelao", name = "Cogumelão", rarity = "Rare", income = 40, price = 2500, shape = "mushroom", color = { 230, 70, 70 } },
	{ id = "olhudo", name = "Olhudo", rarity = "Rare", income = 55, price = 3600, shape = "eye", color = { 120, 90, 230 } },
	{ id = "dragosma", name = "Dragosma", rarity = "Epic", income = 150, price = 13500, shape = "dragon", color = { 60, 200, 150 } },
	{ id = "ciclope_rubi", name = "Ciclope Rubi", rarity = "Epic", income = 200, price = 19000, shape = "cyclops", color = { 220, 40, 80 } },
	{ id = "polvo_neon", name = "Polvo Neon", rarity = "Epic", income = 260, price = 26000, shape = "octopus", color = { 255, 80, 230 } },
	{ id = "rei_gosma", name = "Rei Gosma", rarity = "Legendary", income = 800, price = 120000, shape = "crown", color = { 70, 230, 120 } },
	{ id = "fenix_toxica", name = "Fênix Tóxica", rarity = "Legendary", income = 1100, price = 170000, shape = "phoenix", color = { 255, 120, 40 } },
	{ id = "tita_mutante", name = "Titã Mutante", rarity = "Mythic", income = 4500, price = 1100000, shape = "titan", color = { 110, 120, 140 } },
	{ id = "nucleo_primordial", name = "Núcleo Primordial", rarity = "Mythic", income = 6500, price = 1700000, shape = "core", color = { 60, 255, 220 } },
}
GameConfig.SpeciesById = {}
for i, s in ipairs(GameConfig.Species) do
	s.order = i
	GameConfig.SpeciesById[s.id] = s
end

---------------------------------------------------------------------------
-- mutações (multiplicam renda e valor)
---------------------------------------------------------------------------
GameConfig.MutationOrder = { "normal", "dourada", "diamante", "radioativa", "vazio", "arcoiris" }
GameConfig.Mutations = {
	normal = { id = "normal", name = "Normal", mult = 1, weight = 80, tier = 0 },
	dourada = { id = "dourada", name = "Dourada", mult = 2, weight = 12, tier = 1, color = { 255, 205, 60 } },
	diamante = { id = "diamante", name = "Diamante", mult = 4, weight = 5, tier = 2, color = { 120, 235, 255 } },
	radioativa = { id = "radioativa", name = "Radioativa", mult = 6, weight = 2, tier = 3, color = { 120, 255, 70 } },
	vazio = { id = "vazio", name = "Vazio", mult = 10, weight = 0.8, tier = 4, color = { 120, 50, 200 } },
	arcoiris = { id = "arcoiris", name = "Arco-íris", mult = 20, weight = 0.2, tier = 5, color = { 255, 255, 255 } },
}

---------------------------------------------------------------------------
-- sorte: aumenta o peso das raridades Rara+ e das mutações não normais.
-- As chances finais (já com sorte e eventos) aparecem sempre na interface.
---------------------------------------------------------------------------
GameConfig.Luck = {
	Max = 1.0, -- +100% no máximo
	RarityScale = { [1] = 0, [2] = 0, [3] = 1, [4] = 1.5, [5] = 2, [6] = 2.5 },
	MutationScale = { [0] = 0, [1] = 1, [2] = 1.25, [3] = 1.5, [4] = 1.75, [5] = 2 },
}

---------------------------------------------------------------------------
-- esteira da fábrica (criaturas passam e qualquer jogador pode comprar)
---------------------------------------------------------------------------
GameConfig.Conveyor = {
	SpawnInterval = 3.5, -- segundos entre criaturas
	TravelSeconds = 42, -- tempo para atravessar a esteira
	MaxOnBelt = 14,
	RarityWeights = { Common = 600, Uncommon = 250, Rare = 100, Epic = 38, Legendary = 10, Mythic = 2 },
}

---------------------------------------------------------------------------
-- ovos (quiosques): sorteio pessoal, usa a sorte do jogador
---------------------------------------------------------------------------
GameConfig.EggOrder = { "basico", "raro", "lendario" }
GameConfig.Eggs = {
	basico = {
		id = "basico",
		name = "Ovo Básico",
		price = 300,
		requiredRebirths = 0,
		color = { 120, 220, 120 },
		rarityWeights = { Common = 800, Uncommon = 180, Rare = 18, Epic = 2 },
	},
	raro = {
		id = "raro",
		name = "Ovo Raro",
		price = 10000,
		requiredRebirths = 0,
		color = { 80, 150, 255 },
		rarityWeights = { Uncommon = 450, Rare = 400, Epic = 130, Legendary = 20 },
	},
	lendario = {
		id = "lendario",
		name = "Ovo Lendário",
		price = 100000,
		requiredRebirths = 1,
		color = { 255, 190, 50 },
		rarityWeights = { Rare = 300, Epic = 480, Legendary = 200, Mythic = 20 },
	},
}

---------------------------------------------------------------------------
-- base e melhorias
---------------------------------------------------------------------------
GameConfig.Base = {
	StartSlots = 8,
	MaxSlotsShown = 20,
	StorageSeconds = 1800, -- cada criatura guarda até 30 min de produção (cofre)
	ShieldSeconds = 60, -- escudo da base
	NewcomerShield = 120, -- proteção automática ao entrar
	WalkSpeed = 16,
}
GameConfig.UpgradeOrder = { "slots", "storage", "shield", "speed" }
GameConfig.Upgrades = {
	slots = { id = "slots", name = "Mais pedestais", description = "+2 vagas para criaturas", baseCost = 1500, growth = 4, perLevel = 2, maxLevel = 6 },
	storage = { id = "storage", name = "Cofre maior", description = "+30 min de produção guardada por criatura", baseCost = 800, growth = 3, perLevel = 1800, maxLevel = 7 },
	shield = { id = "shield", name = "Escudo reforçado", description = "+10 s de escudo da base", baseCost = 2500, growth = 3, perLevel = 10, maxLevel = 6 },
	speed = { id = "speed", name = "Tênis turbo", description = "+1 de velocidade ao andar", baseCost = 2000, growth = 2.6, perLevel = 1, maxLevel = 8 },
}

---------------------------------------------------------------------------
-- roubo
---------------------------------------------------------------------------
GameConfig.Steal = {
	HoldSeconds = 1.5, -- segurar o botão para pegar
	MaxCarrySeconds = 45, -- depois disso a criatura volta
	CarrySpeedPenalty = 4, -- quem carrega anda mais devagar
	TagDistance = 7, -- o dono encostar em quem rouba devolve a criatura
	PromptDistance = 9,
	ProtectAfterSteal = 180, -- criatura recém-roubada fica protegida por 3 min
	MinLevelRebirths = 0,
}

---------------------------------------------------------------------------
-- poções (só ganhas no jogo ou compradas com Moedas)
---------------------------------------------------------------------------
GameConfig.PotionOrder = { "sorte", "renda", "velocidade" }
GameConfig.Potions = {
	sorte = { id = "sorte", name = "Poção da Sorte", icon = "🍀", luck = 0.25, duration = 600, maxStack = 3600, coinPrice = 20000, description = "+25% de sorte nos ovos e mutações." },
	renda = { id = "renda", name = "Poção de Renda", icon = "💰", incomeMult = 1.5, duration = 900, maxStack = 5400, coinPrice = 30000, description = "Renda ×1,5 (também enquanto você está fora, até acabar)." },
	velocidade = { id = "velocidade", name = "Poção de Velocidade", icon = "👟", speed = 6, duration = 300, maxStack = 1800, coinPrice = 8000, description = "+6 de velocidade para fugir ou perseguir." },
}

---------------------------------------------------------------------------
-- renascimento
---------------------------------------------------------------------------
GameConfig.Rebirth = {
	MaxRebirths = 20,
	BaseCost = 250000,
	Growth = 4,
	IncomeBonusPer = 0.5, -- +50% de renda por renascimento
	LuckPer = 0.05, -- +5% de sorte por renascimento
	LuckMax = 0.5,
	ConfirmPhrase = "RENASCER",
}
function GameConfig.rebirthCost(n)
	return math.floor(GameConfig.Rebirth.BaseCost * (GameConfig.Rebirth.Growth ^ (n - 1)) + 0.5)
end

---------------------------------------------------------------------------
-- limites de frequência por categoria (balde de fichas por jogador)
---------------------------------------------------------------------------
GameConfig.RateLimits = {
	Data = { capacity = 6, refillPerSecond = 1 },
	Hatch = { capacity = 4, refillPerSecond = 2 },
	Base = { capacity = 10, refillPerSecond = 4 },
	Claim = { capacity = 8, refillPerSecond = 2 },
	Settings = { capacity = 6, refillPerSecond = 1 },
	Ranking = { capacity = 3, refillPerSecond = 0.5 },
}

---------------------------------------------------------------------------
-- utilidades
---------------------------------------------------------------------------
function GameConfig.tier(rarityId)
	local r = GameConfig.Rarities[rarityId]
	return r and r.tier or 0
end

function GameConfig.upgradeCost(id, level)
	local u = GameConfig.Upgrades[id]
	return math.floor(u.baseCost * (u.growth ^ level) + 0.5)
end

return GameConfig
