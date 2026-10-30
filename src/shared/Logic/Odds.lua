-- Sorteio das máquinas. Usado SOMENTE pelo servidor para sortear e pela interface para
-- mostrar as chances: os dois leem a mesma tabela de MachineDefinitions.

local Shared = script.Parent.Parent
local MachineDefinitions = require(Shared.MachineDefinitions)
local ItemDefinitions = require(Shared.ItemDefinitions)
local RarityConfig = require(Shared.RarityConfig)

local Odds = {}

function Odds.total(machine)
	local sum = 0
	for _, entry in ipairs(machine.pool) do
		sum = sum + entry.chance
	end
	return sum
end

-- r: número em [0, 1) vindo de Random (servidor). Retorna o id do objeto.
function Odds.pick(machine, r)
	local target = r * Odds.total(machine)
	local acc = 0
	for _, entry in ipairs(machine.pool) do
		acc = acc + entry.chance
		if target < acc then
			return entry.item
		end
	end
	return machine.pool[#machine.pool].item
end

-- lista para a interface: { item, name, rarity, rarityName, chance, value }, da mais rara para a mais comum
function Odds.display(machineId)
	local machine = MachineDefinitions.get(machineId)
	local out = {}
	if not machine then
		return out
	end
	local total = Odds.total(machine)
	for _, entry in ipairs(machine.pool) do
		local item = ItemDefinitions.get(entry.item)
		table.insert(out, {
			item = entry.item,
			name = item.name,
			rarity = item.rarity,
			rarityName = RarityConfig.get(item.rarity).name,
			chance = entry.chance * 100 / total,
			value = item.value,
		})
	end
	table.sort(out, function(a, b)
		local ra, rb = RarityConfig.rank(a.rarity), RarityConfig.rank(b.rarity)
		if ra ~= rb then
			return ra > rb
		end
		return a.chance < b.chance
	end)
	return out
end

-- valor médio de venda por abertura (para balanceamento e testes)
function Odds.expectedValue(machine)
	local total = Odds.total(machine)
	local ev = 0
	for _, entry in ipairs(machine.pool) do
		ev = ev + ItemDefinitions.get(entry.item).value * entry.chance / total
	end
	return ev
end

return Odds
