-- SkinDefinitions: as 60 skins originais, geradas a partir de CaseCatalog.
-- Nomes de armas e acabamentos são fictícios e próprios do CASE STRIKE RNG.
-- Modelos 3D estilizados gerados por código (Shared/Visual/SkinModelFactory), sem IDs de assets.
--
-- Valor de catálogo: preço da caixa × fator da raridade × variação, escalado por caixa para que o
-- valor esperado de uma abertura seja CaseCatalog.TargetExpectedValue × preço.

local Shared = script.Parent.Parent
local RarityConfig = require(Shared.Config.RarityConfig)
local CaseCatalog = require(Shared.Config.CaseCatalog)

local SkinDefinitions = {}

SkinDefinitions.Categories = {
	Pistol = { id = "Pistol", displayName = "Pistola" },
	SMG = { id = "SMG", displayName = "Submetralhadora" },
	Rifle = { id = "Rifle", displayName = "Rifle" },
	Sniper = { id = "Sniper", displayName = "Arma de precisão" },
	Knife = { id = "Knife", displayName = "Faca" },
}

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

-- Variação de valor dentro de uma raridade (média 1,0)
local VARIANCE = {
	[1] = { 1.0 },
	[2] = { 0.9, 1.1 },
	[3] = { 0.85, 1.0, 1.15 },
}

SkinDefinitions.List = {}
SkinDefinitions.ById = {}
SkinDefinitions.ByCase = {}
SkinDefinitions.CasePrices = {}

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

-- peso de raridade usado por uma caixa (também usado por CaseDefinitions)
function SkinDefinitions.rarityWeight(caseEntry, rarityId)
	local w = caseEntry.rarityWeights and caseEntry.rarityWeights[rarityId]
	if w == nil then
		w = RarityConfig.BaseWeights[rarityId]
	end
	return w or 0
end

local PATTERNS = { "stripes", "bands", "solid", "panels" }

for _, entry in ipairs(CaseCatalog.List) do
	local caseId = entry.id
	SkinDefinitions.CasePrices[caseId] = entry.price
	SkinDefinitions.ByCase[caseId] = {}

	local perRarity = {}
	for _, row in ipairs(entry.skins) do
		perRarity[row[1]] = (perRarity[row[1]] or 0) + 1
	end
	local totalWeight = 0
	for rarityId in pairs(perRarity) do
		totalWeight = totalWeight + SkinDefinitions.rarityWeight(entry, rarityId)
	end

	-- 1ª passada: valor bruto e valor esperado bruto
	local seen = {}
	local raws = {}
	local evRaw = 0
	for i, row in ipairs(entry.skins) do
		local rarityId = row[1]
		seen[rarityId] = (seen[rarityId] or 0) + 1
		local variance = VARIANCE[perRarity[rarityId]] or { 1.0 }
		local v = variance[seen[rarityId]] or 1.0
		local raw = entry.price * RarityConfig.ValueFactor[rarityId] * v
		raws[i] = raw
		local p = (SkinDefinitions.rarityWeight(entry, rarityId) / perRarity[rarityId]) / totalWeight
		evRaw = evRaw + p * raw
	end
	local scale = (CaseCatalog.TargetExpectedValue * entry.price) / evRaw

	-- 2ª passada: definições finais
	for i, row in ipairs(entry.skins) do
		local rarityId, weaponKey, finish = row[1], row[2], row[3]
		local weapon = SkinDefinitions.Weapons[weaponKey]
		assert(weapon, "arma desconhecida: " .. tostring(weaponKey))
		assert(RarityConfig.Rarities[rarityId], "raridade desconhecida: " .. tostring(rarityId))
		local palette = entry.palette
		local tier = RarityConfig.tier(rarityId)
		local def = {
			id = caseId .. "_" .. pad2(i),
			name = weapon.name .. " | " .. finish,
			weaponName = weapon.name,
			finish = finish,
			weaponKey = weaponKey,
			category = weapon.category,
			rarity = rarityId,
			value = math.max(1, math.floor(raws[i] * scale + 0.5)),
			collection = caseId,
			caseId = caseId,
			visual = {
				primary = palette[(i % 3) + 1],
				secondary = palette[((i + 1) % 3) + 1],
				accent = blend(RarityConfig.Rarities[rarityId].color, palette[1], 0.25),
				glow = tier >= 5,
				pattern = PATTERNS[(i % 4) + 1],
				placeholderModel = false, -- modelo estilizado próprio (gerado por código)
			},
		}
		table.insert(SkinDefinitions.List, def)
		SkinDefinitions.ById[def.id] = def
		table.insert(SkinDefinitions.ByCase[caseId], def)
	end
end

SkinDefinitions.Count = #SkinDefinitions.List

function SkinDefinitions.get(defId)
	return SkinDefinitions.ById[defId]
end

return SkinDefinitions
