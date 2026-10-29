-- Odds: tabelas de chance de espécies e mutações (com sorte e eventos).
-- O servidor sorteia com estas funções; o cliente usa as MESMAS para exibir as chances.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)

local Odds = {}

local function clampLuck(luck)
	return math.max(0, math.min(luck or 0, GameConfig.Luck.Max))
end

-- rarityWeights = { Common = n, ... } (de um ovo ou da esteira)
-- Retorna lista { speciesId, rarity, p } (soma 1). O peso de uma raridade é dividido
-- igualmente entre as espécies daquela raridade.
function Odds.speciesTable(rarityWeights, luck)
	luck = clampLuck(luck)
	local byRarity = {}
	for _, s in ipairs(GameConfig.Species) do
		byRarity[s.rarity] = byRarity[s.rarity] or {}
		table.insert(byRarity[s.rarity], s)
	end
	local entries, total = {}, 0
	for _, rid in ipairs(GameConfig.RarityOrder) do
		local w = rarityWeights[rid]
		local list = byRarity[rid]
		if w and w > 0 and list then
			local tier = GameConfig.tier(rid)
			local scaled = w * (1 + luck * (GameConfig.Luck.RarityScale[tier] or 0))
			for _, s in ipairs(list) do
				local ew = scaled / #list
				total = total + ew
				table.insert(entries, { speciesId = s.id, rarity = rid, weight = ew, p = 0 })
			end
		end
	end
	assert(total > 0, "tabela de espécies vazia")
	for _, e in ipairs(entries) do
		e.p = e.weight / total
	end
	return entries
end

-- event (opcional) = evento ativo (EventConfig.at); kind "mutation" multiplica o peso de uma mutação
function Odds.mutationTable(luck, event)
	luck = clampLuck(luck)
	local entries, total = {}, 0
	for _, mid in ipairs(GameConfig.MutationOrder) do
		local m = GameConfig.Mutations[mid]
		local w = m.weight * (1 + luck * (GameConfig.Luck.MutationScale[m.tier] or 0))
		if event and event.kind == "mutation" and event.mutation == mid then
			w = w * event.weightMult
		end
		total = total + w
		table.insert(entries, { mutationId = mid, weight = w, p = 0 })
	end
	for _, e in ipairs(entries) do
		e.p = e.weight / total
	end
	return entries
end

function Odds.pick(entries, r)
	local acc = 0
	for _, e in ipairs(entries) do
		acc = acc + e.p
		if r < acc then
			return e
		end
	end
	return entries[#entries]
end

-- chance agregada por raridade
function Odds.byRarity(entries)
	local out = {}
	for _, e in ipairs(entries) do
		out[e.rarity] = (out[e.rarity] or 0) + e.p
	end
	return out
end

-- percentuais arredondados que somam exatamente 100 (método do maior resto)
function Odds.displayPercents(entries, decimals)
	decimals = decimals or 2
	local unit = 10 ^ decimals
	local totalUnits = math.floor(100 * unit + 0.5)
	local floors, rems, used = {}, {}, 0
	for i, e in ipairs(entries) do
		local exact = e.p * 100 * unit
		floors[i] = math.floor(exact)
		rems[i] = { i = i, r = exact - floors[i] }
		used = used + floors[i]
	end
	table.sort(rems, function(a, b)
		if a.r == b.r then
			return a.i < b.i
		end
		return a.r > b.r
	end)
	local k = 1
	while used < totalUnits and #rems > 0 do
		floors[rems[k].i] = floors[rems[k].i] + 1
		used = used + 1
		k = (k % #rems) + 1
	end
	local out = {}
	for i = 1, #entries do
		out[i] = floors[i] / unit
	end
	return out
end

-- valor esperado (em moedas) de um ovo, sem sorte
function Odds.expectedEggValue(egg, luck, event)
	local sp = Odds.speciesTable(egg.rarityWeights, luck)
	local mu = Odds.mutationTable(luck, event)
	local avgMult = 0
	for _, e in ipairs(mu) do
		avgMult = avgMult + e.p * GameConfig.Mutations[e.mutationId].mult
	end
	local ev = 0
	for _, e in ipairs(sp) do
		ev = ev + e.p * GameConfig.SpeciesById[e.speciesId].price
	end
	return ev * avgMult
end

return Odds
