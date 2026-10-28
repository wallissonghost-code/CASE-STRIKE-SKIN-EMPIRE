-- CaseDefinitions: as 12 caixas (a partir de CaseCatalog) e suas tabelas reais de recompensas.
-- Pesos por raridade configuráveis por caixa; dentro de uma raridade, divididos igualmente.

local Shared = script.Parent.Parent
local CaseCatalog = require(Shared.Config.CaseCatalog)
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local RarityConfig = require(Shared.Config.RarityConfig)

local CaseDefinitions = {}

CaseDefinitions.List = {}
CaseDefinitions.ById = {}

-- skins de um "pool" (caixas especiais/limitadas): filtro sobre skins existentes
local function poolSkins(pool)
	local allowed = nil
	if pool.collections then
		allowed = {}
		for _, c in ipairs(pool.collections) do
			allowed[c] = true
		end
	end
	local out = {}
	for _, s in ipairs(SkinDefinitions.List) do
		local tier = RarityConfig.tier(s.rarity)
		if (not pool.category or s.category == pool.category)
			and (not allowed or allowed[s.collection])
			and (not pool.minTier or tier >= pool.minTier)
			and (not pool.maxTier or tier <= pool.maxTier)
		then
			table.insert(out, s)
		end
	end
	return out
end

for order, entry in ipairs(CaseCatalog.List) do
	local skins = entry.skins and SkinDefinitions.ByCase[entry.id] or poolSkins(entry.pool or {})
	local perRarity = {}
	for _, s in ipairs(skins) do
		perRarity[s.rarity] = (perRarity[s.rarity] or 0) + 1
	end
	local drops = {}
	for _, s in ipairs(skins) do
		table.insert(drops, {
			skinId = s.id,
			rarity = s.rarity,
			weight = SkinDefinitions.rarityWeight(entry, s.rarity) / perRarity[s.rarity],
		})
	end
	-- preço: o configurado, ou o valor esperado do sorteio dividido pelo EV alvo (sem desconto)
	local price = entry.price
	if not price then
		local total, ev = 0, 0
		for _, d in ipairs(drops) do
			total = total + d.weight
		end
		for _, d in ipairs(drops) do
			ev = ev + (d.weight / total) * SkinDefinitions.ById[d.skinId].value
		end
		price = math.max(1, math.floor(ev / CaseCatalog.TargetExpectedValue + 0.5))
	end
	local def = {
		id = entry.id,
		section = entry.section or "level",
		isCollection = entry.skins ~= nil,
		stockPerDay = entry.stockPerDay,
		order = order,
		name = entry.name,
		collectionName = entry.collection or entry.name,
		theme = entry.theme,
		price = price,
		requiredLevel = entry.requiredLevel,
		color = entry.color,
		trim = entry.trim,
		eventId = entry.eventId,
		available = true,
		drops = drops,
	}
	table.insert(CaseDefinitions.List, def)
	CaseDefinitions.ById[def.id] = def
end

-- Quantidades de abertura. 25 exige o atributo "Limite de abertura múltipla" (AttributeConfig).
CaseDefinitions.AllowedQuantities = { [1] = true, [5] = true, [10] = true, [25] = true }
CaseDefinitions.QuantityOrder = { 1, 5, 10, 25 }

-- só as caixas que formam coleção (Índice, recompensas de coleção)
CaseDefinitions.Collections = {}
for _, c in ipairs(CaseDefinitions.List) do
	if c.isCollection then
		table.insert(CaseDefinitions.Collections, c)
	end
end

function CaseDefinitions.get(caseId)
	return CaseDefinitions.ById[caseId]
end

return CaseDefinitions
