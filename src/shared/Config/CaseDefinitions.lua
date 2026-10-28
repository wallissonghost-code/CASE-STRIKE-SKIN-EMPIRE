-- CaseDefinitions: as seis caixas originais e suas tabelas reais de recompensas.
-- Preços em SkinDefinitions.CasePrices (valores iniciais de balanceamento, configuráveis).

local Shared = script.Parent.Parent
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local RarityConfig = require(Shared.Config.RarityConfig)

local CaseDefinitions = {}

local META = {
	{
		id = "urban",
		name = "Caixa Urban",
		theme = "Concreto e grafite da cidade",
		requiredLevel = 1,
		color = { 130, 135, 145 },
		trim = { 230, 110, 60 },
	},
	{
		id = "tactical",
		name = "Caixa Tactical",
		theme = "Equipamento militar e camuflagem",
		requiredLevel = 1,
		color = { 95, 110, 70 },
		trim = { 200, 180, 120 },
	},
	{
		id = "neon",
		name = "Caixa Neon",
		theme = "Fliperama, synthwave e luz",
		requiredLevel = 3,
		color = { 60, 25, 100 },
		trim = { 255, 70, 200 },
	},
	{
		id = "shadow",
		name = "Caixa Shadow",
		theme = "Fumaça, eclipse e trevas",
		requiredLevel = 6,
		color = { 30, 28, 40 },
		trim = { 140, 90, 220 },
	},
	{
		id = "elite",
		name = "Caixa Elite",
		theme = "Porcelana, mármore e ouro branco",
		requiredLevel = 10,
		color = { 235, 235, 240 },
		trim = { 215, 180, 90 },
	},
	{
		id = "imperial",
		name = "Caixa Imperial",
		theme = "Dinastias, brasões e dragões",
		requiredLevel = 15,
		color = { 150, 20, 30 },
		trim = { 240, 190, 60 },
	},
}

CaseDefinitions.List = {}
CaseDefinitions.ById = {}

for order, meta in ipairs(META) do
	local skins = SkinDefinitions.ByCase[meta.id]
	assert(skins and #skins > 0, "caixa sem skins: " .. meta.id)

	-- quantas skins de cada raridade a caixa tem
	local perRarity = {}
	for _, s in ipairs(skins) do
		perRarity[s.rarity] = (perRarity[s.rarity] or 0) + 1
	end

	-- peso de cada skin = peso da raridade dividido igualmente entre as skins dela
	local drops = {}
	for _, s in ipairs(skins) do
		table.insert(drops, {
			skinId = s.id,
			rarity = s.rarity,
			weight = RarityConfig.BaseWeights[s.rarity] / perRarity[s.rarity],
		})
	end

	local def = {
		id = meta.id,
		order = order,
		name = meta.name,
		theme = meta.theme,
		price = SkinDefinitions.CasePrices[meta.id],
		requiredLevel = meta.requiredLevel,
		color = meta.color,
		trim = meta.trim,
		available = true, -- indicador de disponibilidade (pode ser desligado por evento/manutenção)
		drops = drops,
	}
	table.insert(CaseDefinitions.List, def)
	CaseDefinitions.ById[def.id] = def
end

CaseDefinitions.AllowedQuantities = { [1] = true, [5] = true, [10] = true }

function CaseDefinitions.get(caseId)
	return CaseDefinitions.ById[caseId]
end

return CaseDefinitions
