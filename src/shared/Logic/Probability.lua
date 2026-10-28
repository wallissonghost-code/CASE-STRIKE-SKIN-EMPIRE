-- Probability: cálculo transparente das chances de cada skin em uma caixa.
-- O servidor usa estas funções para sortear; o cliente usa as MESMAS funções
-- (com a sorte informada pelo servidor) apenas para exibir. A soma é sempre 100%.

local Shared = script.Parent.Parent
local RarityConfig = require(Shared.Config.RarityConfig)
local LuckConfig = require(Shared.Config.LuckConfig)

local Probability = {}

-- Retorna lista de { skinId, rarity, weight, probability } com probabilidades normalizadas.
function Probability.computeTable(caseDef, luck)
	luck = math.max(0, math.min(luck or 0, LuckConfig.MaxTotalLuck))
	local entries = {}
	local total = 0
	for _, drop in ipairs(caseDef.drops) do
		local tier = RarityConfig.tier(drop.rarity)
		local scale = LuckConfig.TierScale[tier] or 0
		local w = drop.weight * (1 + luck * scale)
		total = total + w
		table.insert(entries, { skinId = drop.skinId, rarity = drop.rarity, weight = w, probability = 0 })
	end
	assert(total > 0, "caixa sem pesos válidos")
	for _, e in ipairs(entries) do
		e.probability = e.weight / total
	end
	return entries
end

-- Sorteia uma entrada usando um número aleatório em [0, 1).
function Probability.pick(entries, r)
	local acc = 0
	for _, e in ipairs(entries) do
		acc = acc + e.probability
		if r < acc then
			return e
		end
	end
	return entries[#entries] -- proteção contra arredondamento
end

-- Probabilidades por raridade (somadas).
function Probability.byRarity(entries)
	local out = {}
	for _, e in ipairs(entries) do
		out[e.rarity] = (out[e.rarity] or 0) + e.probability
	end
	return out
end

-- Valor esperado de uma abertura.
function Probability.expectedValue(entries, skinDefs)
	local ev = 0
	for _, e in ipairs(entries) do
		ev = ev + e.probability * skinDefs.ById[e.skinId].value
	end
	return ev
end

-- Percentuais arredondados para exibição que somam exatamente 100 (método do maior resto).
-- decimals: casas decimais do percentual (padrão 3 → unidades de 0,001%).
function Probability.displayPercents(entries, decimals)
	decimals = decimals or 3
	local unit = 10 ^ decimals
	local totalUnits = math.floor(100 * unit + 0.5)
	local floors, rems = {}, {}
	local used = 0
	for i, e in ipairs(entries) do
		local exact = e.probability * 100 * unit
		local f = math.floor(exact)
		floors[i] = f
		rems[i] = { i = i, r = exact - f }
		used = used + f
	end
	table.sort(rems, function(a, b)
		if a.r == b.r then
			return a.i < b.i
		end
		return a.r > b.r
	end)
	local missing = totalUnits - used
	local k = 1
	while missing > 0 and #rems > 0 do
		local idx = rems[((k - 1) % #rems) + 1].i
		floors[idx] = floors[idx] + 1
		missing = missing - 1
		k = k + 1
	end
	local out = {}
	for i = 1, #entries do
		out[i] = floors[i] / unit
	end
	return out
end

return Probability
