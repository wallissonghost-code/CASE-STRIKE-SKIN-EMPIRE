-- SkinDefinitions: as 60 skins originais do jogo.
-- Nomes de armas e acabamentos são fictícios e próprios do CASE STRIKE.
-- Os modelos 3D são PROVISÓRIOS: gerados por código (Shared/Visual/SkinModelFactory)
-- a partir de peças básicas. Nenhum ID de asset externo é utilizado.

local Shared = script.Parent.Parent
local RarityConfig = require(Shared.Config.RarityConfig)

local SkinDefinitions = {}

SkinDefinitions.Categories = {
	Pistol = { id = "Pistol", displayName = "Pistola" },
	SMG = { id = "SMG", displayName = "Submetralhadora" },
	Rifle = { id = "Rifle", displayName = "Rifle" },
	Sniper = { id = "Sniper", displayName = "Rifle de precisão" },
	Knife = { id = "Knife", displayName = "Faca colecionável" },
}

-- Modelos fictícios de armas (base de cada skin).
SkinDefinitions.Weapons = {
	VespaP9 = { name = "Vespa P9", category = "Pistol" },
	Mako45 = { name = "Mako 45", category = "Pistol" },
	RookR1 = { name = "Rook R1", category = "Pistol" },
	HornetMX = { name = "Hornet MX", category = "SMG" },
	RatchetV = { name = "Ratchet V", category = "SMG" },
	WaspK7 = { name = "Wasp K7", category = "SMG" },
	TalonAR = { name = "Talon AR", category = "Rifle" },
	BastionR7 = { name = "Bastion R7", category = "Rifle" },
	GaleC4 = { name = "Gale C4", category = "Rifle" },
	LongbowSR = { name = "Longbow SR", category = "Sniper" },
	Kestrel50 = { name = "Kestrel 50", category = "Sniper" },
	FangKarambit = { name = "Fang Karambit", category = "Knife" },
	CorvoFaca = { name = "Faca Corvo", category = "Knife" },
	BowieAtlas = { name = "Bowie Atlas", category = "Knife" },
	LiraBorboleta = { name = "Lira Borboleta", category = "Knife" },
}

-- Paleta de cada caixa (usada pelos modelos provisórios).
SkinDefinitions.CasePalettes = {
	urban = { { 120, 124, 130 }, { 70, 72, 78 }, { 200, 90, 60 } },
	tactical = { { 96, 110, 70 }, { 170, 150, 110 }, { 60, 66, 50 } },
	neon = { { 255, 70, 200 }, { 40, 230, 255 }, { 30, 20, 60 } },
	shadow = { { 30, 28, 40 }, { 90, 60, 140 }, { 15, 15, 20 } },
	elite = { { 235, 235, 240 }, { 210, 180, 90 }, { 60, 110, 200 } },
	imperial = { { 170, 25, 35 }, { 235, 185, 60 }, { 40, 120, 80 } },
}

-- Linhas: { caseId, rarityId, weaponKey, finish }
-- Ordem dentro da caixa define o índice (id = caseId_NN).
local ROWS = {
	-- URBAN
	{ "urban", "Common", "VespaP9", "Concreto" },
	{ "urban", "Common", "HornetMX", "Grafite Urbano" },
	{ "urban", "Common", "TalonAR", "Asfalto" },
	{ "urban", "Uncommon", "Mako45", "Pichação" },
	{ "urban", "Uncommon", "RatchetV", "Tijolo Vermelho" },
	{ "urban", "Rare", "BastionR7", "Metrô Noturno" },
	{ "urban", "Rare", "LongbowSR", "Viaduto" },
	{ "urban", "Epic", "GaleC4", "Arranha-Céu" },
	{ "urban", "Legendary", "FangKarambit", "Beco Dourado" },
	{ "urban", "Secret", "CorvoFaca", "Sinal Vermelho" },
	-- TACTICAL
	{ "tactical", "Common", "RookR1", "Oliva" },
	{ "tactical", "Common", "WaspK7", "Areia" },
	{ "tactical", "Common", "TalonAR", "Floresta Fosca" },
	{ "tactical", "Uncommon", "Kestrel50", "Camuflagem Digital" },
	{ "tactical", "Uncommon", "HornetMX", "Patrulha" },
	{ "tactical", "Rare", "VespaP9", "Operador" },
	{ "tactical", "Rare", "BastionR7", "Ranger" },
	{ "tactical", "Epic", "LongbowSR", "Atirador Fantasma" },
	{ "tactical", "Legendary", "BowieAtlas", "Comando" },
	{ "tactical", "Secret", "FangKarambit", "Insígnia Carmesim" },
	-- NEON
	{ "neon", "Common", "Mako45", "Pixel Rosa" },
	{ "neon", "Common", "RatchetV", "Fliperama" },
	{ "neon", "Common", "GaleC4", "Circuito" },
	{ "neon", "Uncommon", "WaspK7", "Onda Synth" },
	{ "neon", "Uncommon", "RookR1", "Laser Azul" },
	{ "neon", "Rare", "TalonAR", "Holograma" },
	{ "neon", "Rare", "Kestrel50", "Cidade Elétrica" },
	{ "neon", "Epic", "HornetMX", "Pulso Ultravioleta" },
	{ "neon", "Legendary", "LiraBorboleta", "Prisma" },
	{ "neon", "Secret", "BastionR7", "Sobrecarga" },
	-- SHADOW
	{ "shadow", "Common", "VespaP9", "Fumaça" },
	{ "shadow", "Common", "WaspK7", "Eclipse Fosco" },
	{ "shadow", "Common", "LongbowSR", "Carvão" },
	{ "shadow", "Uncommon", "RatchetV", "Névoa" },
	{ "shadow", "Uncommon", "GaleC4", "Corvo Negro" },
	{ "shadow", "Rare", "Mako45", "Abismo" },
	{ "shadow", "Rare", "TalonAR", "Meia-Noite" },
	{ "shadow", "Epic", "Kestrel50", "Espectro" },
	{ "shadow", "Legendary", "CorvoFaca", "Lua Nova" },
	{ "shadow", "Secret", "LiraBorboleta", "Vazio Absoluto" },
	-- ELITE
	{ "elite", "Common", "RookR1", "Porcelana" },
	{ "elite", "Common", "HornetMX", "Marfim" },
	{ "elite", "Common", "BastionR7", "Platina Fosca" },
	{ "elite", "Uncommon", "VespaP9", "Filigrana" },
	{ "elite", "Uncommon", "LongbowSR", "Mármore" },
	{ "elite", "Rare", "RatchetV", "Ouro Branco" },
	{ "elite", "Rare", "GaleC4", "Safira" },
	{ "elite", "Epic", "TalonAR", "Coroa de Louros" },
	{ "elite", "Legendary", "FangKarambit", "Esmeralda Real" },
	{ "elite", "Secret", "Kestrel50", "Diamante Negro" },
	-- IMPERIAL
	{ "imperial", "Common", "WaspK7", "Brasão" },
	{ "imperial", "Common", "Mako45", "Seda Escarlate" },
	{ "imperial", "Common", "RookR1", "Bronze Antigo" },
	{ "imperial", "Uncommon", "HornetMX", "Dragão de Jade" },
	{ "imperial", "Uncommon", "BastionR7", "Estandarte" },
	{ "imperial", "Rare", "Kestrel50", "Fênix" },
	{ "imperial", "Rare", "LongbowSR", "Trono" },
	{ "imperial", "Epic", "GaleC4", "Dinastia" },
	{ "imperial", "Legendary", "BowieAtlas", "Imperador" },
	{ "imperial", "Secret", "LiraBorboleta", "Sol Eterno" },
}

-- Preço de cada caixa (fonte única; CaseDefinitions lê daqui).
SkinDefinitions.CasePrices = {
	urban = 25,
	tactical = 75,
	neon = 200,
	shadow = 600,
	elite = 1500,
	imperial = 5000,
}

-- Variação de valor dentro de uma raridade (média 1,0 para manter o valor esperado).
local VARIANCE = {
	[1] = { 1.0 },
	[2] = { 0.9, 1.1 },
	[3] = { 0.85, 1.0, 1.15 },
}

SkinDefinitions.List = {} -- em ordem
SkinDefinitions.ById = {}
SkinDefinitions.ByCase = {}

local function pad2(n)
	if n < 10 then
		return "0" .. tostring(n)
	end
	return tostring(n)
end

local function blend(a, b, t)
	return {
		math.floor(a[1] + (b[1] - a[1]) * t + 0.5),
		math.floor(a[2] + (b[2] - a[2]) * t + 0.5),
		math.floor(a[3] + (b[3] - a[3]) * t + 0.5),
	}
end

do
	-- conta skins por (caixa, raridade) para aplicar a variância
	local counts = {}
	for _, row in ipairs(ROWS) do
		local key = row[1] .. ":" .. row[2]
		counts[key] = (counts[key] or 0) + 1
	end
	local seen = {}
	local indexInCase = {}
	for _, row in ipairs(ROWS) do
		local caseId, rarityId, weaponKey, finish = row[1], row[2], row[3], row[4]
		local weapon = SkinDefinitions.Weapons[weaponKey]
		assert(weapon, "arma desconhecida: " .. tostring(weaponKey))
		local key = caseId .. ":" .. rarityId
		seen[key] = (seen[key] or 0) + 1
		indexInCase[caseId] = (indexInCase[caseId] or 0) + 1
		local variance = VARIANCE[counts[key]] or { 1.0 }
		local v = variance[seen[key]] or 1.0
		local price = SkinDefinitions.CasePrices[caseId]
		local value = math.max(1, math.floor(price * RarityConfig.ValueFactor[rarityId] * v + 0.5))
		local palette = SkinDefinitions.CasePalettes[caseId]
		local idx = indexInCase[caseId]
		local primary = palette[(idx % 3) + 1]
		local secondary = palette[((idx + 1) % 3) + 1]
		local accent = blend(RarityConfig.Rarities[rarityId].color, palette[1], 0.25)
		local tier = RarityConfig.tier(rarityId)

		local def = {
			id = caseId .. "_" .. pad2(idx),
			name = weapon.name .. " | " .. finish,
			weaponName = weapon.name,
			finish = finish,
			weaponKey = weaponKey,
			category = weapon.category,
			rarity = rarityId,
			value = value,
			collection = caseId, -- cada caixa forma uma coleção
			caseId = caseId,
			visual = {
				primary = primary,
				secondary = secondary,
				accent = accent,
				glow = tier >= 5,
				pattern = (idx % 4 == 0) and "stripes" or ((idx % 4 == 1) and "bands" or ((idx % 4 == 2) and "solid" or "panels")),
				placeholderModel = true, -- MODELO PROVISÓRIO: substituir antes da publicação
			},
		}
		table.insert(SkinDefinitions.List, def)
		SkinDefinitions.ById[def.id] = def
		SkinDefinitions.ByCase[caseId] = SkinDefinitions.ByCase[caseId] or {}
		table.insert(SkinDefinitions.ByCase[caseId], def)
	end
end

SkinDefinitions.Count = #SkinDefinitions.List

function SkinDefinitions.get(defId)
	return SkinDefinitions.ById[defId]
end

return SkinDefinitions
