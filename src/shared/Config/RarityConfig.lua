-- RarityConfig: definição das seis raridades.
-- Observação: os arquivos de src/shared usam um subconjunto de Luau compatível
-- com Lua 5.x para que a lógica possa ser testada fora do Roblox (ver tests/).

local RarityConfig = {}

RarityConfig.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Secret" }

RarityConfig.Rarities = {
	Common = {
		id = "Common",
		tier = 1,
		displayName = "Comum",
		color = { 165, 170, 180 }, -- cinza
		bankMultiplier = 1.00,
		discoverXp = 10,
	},
	Uncommon = {
		id = "Uncommon",
		tier = 2,
		displayName = "Incomum",
		color = { 80, 200, 110 }, -- verde
		bankMultiplier = 1.05,
		discoverXp = 20,
	},
	Rare = {
		id = "Rare",
		tier = 3,
		displayName = "Rara",
		color = { 70, 140, 255 }, -- azul
		bankMultiplier = 1.12,
		discoverXp = 40,
	},
	Epic = {
		id = "Epic",
		tier = 4,
		displayName = "Épica",
		color = { 170, 85, 245 }, -- roxo
		bankMultiplier = 1.20,
		discoverXp = 80,
	},
	Legendary = {
		id = "Legendary",
		tier = 5,
		displayName = "Lendária",
		color = { 245, 190, 50 }, -- dourado
		bankMultiplier = 1.30,
		discoverXp = 160,
	},
	Secret = {
		id = "Secret",
		tier = 6,
		displayName = "Secreta",
		color = { 235, 55, 65 }, -- vermelho
		bankMultiplier = 1.40,
		discoverXp = 300,
	},
}

-- Peso base de sorteio por raridade (antes de modificadores de sorte).
-- Somam 1.0 por caixa quando cada raridade está presente.
RarityConfig.BaseWeights = {
	Common = 0.62,
	Uncommon = 0.22,
	Rare = 0.10,
	Epic = 0.04,
	Legendary = 0.015,
	Secret = 0.005,
}

-- Multiplicador de valor em relação ao preço da caixa.
-- Valor esperado por abertura ~0,90x o preço (a caixa é um consumo de créditos;
-- a renda do banco e as missões compensam).
RarityConfig.ValueFactor = {
	Common = 0.30,
	Uncommon = 0.60,
	Rare = 1.40,
	Epic = 3.50,
	Legendary = 10.0,
	Secret = 30.0,
}

function RarityConfig.get(id)
	return RarityConfig.Rarities[id]
end

function RarityConfig.tier(id)
	local r = RarityConfig.Rarities[id]
	return r and r.tier or 0
end

return RarityConfig
