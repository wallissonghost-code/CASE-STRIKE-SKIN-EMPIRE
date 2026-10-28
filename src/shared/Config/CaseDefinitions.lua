-- CaseDefinitions: as 12 caixas (a partir de CaseCatalog) e suas tabelas reais de recompensas.
-- Pesos por raridade configuráveis por caixa; dentro de uma raridade, divididos igualmente.

local Shared = script.Parent.Parent
local CaseCatalog = require(Shared.Config.CaseCatalog)
local SkinDefinitions = require(Shared.Config.SkinDefinitions)

local CaseDefinitions = {}

CaseDefinitions.List = {}
CaseDefinitions.ById = {}

for order, entry in ipairs(CaseCatalog.List) do
	local skins = SkinDefinitions.ByCase[entry.id]
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
	local def = {
		id = entry.id,
		order = order,
		name = entry.name,
		collectionName = entry.collection,
		theme = entry.theme,
		price = entry.price,
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

function CaseDefinitions.get(caseId)
	return CaseDefinitions.ById[caseId]
end

return CaseDefinitions
