-- Melhorias compradas com Coins. Nenhuma melhoria altera probabilidades de sorteio.
-- prices[n] = preço para ir do nível n-1 ao nível n. max = #prices.

local UpgradeConfig = {}

UpgradeConfig.Order = { "capacity", "speed", "missionBonus", "showcase" }

UpgradeConfig.Upgrades = {
	capacity = {
		name = "Capacidade do inventário",
		icon = "🎒",
		description = "Guarde mais objetos.",
		prices = { 200, 500, 1200, 3000, 7000, 15000 },
		base = 40,
		perLevel = 20,
	},
	speed = {
		name = "Velocidade de abertura",
		icon = "⚡",
		description = "A animação da máquina fica mais curta.",
		prices = { 300, 900, 2500, 6000 },
		durations = { 4.0, 3.4, 2.8, 2.3, 1.8 }, -- índice = nível + 1
	},
	missionBonus = {
		name = "Recompensas de missões",
		icon = "📜",
		description = "+10% de Coins em missões e presentes por nível.",
		prices = { 400, 1000, 2500, 6000, 12000 },
		perLevel = 0.10,
	},
	showcase = {
		name = "Vitrines",
		icon = "🏛️",
		description = "Mais espaços para expor objetos.",
		prices = { 250, 800, 2500, 7000 },
		base = 2,
		perLevel = 1,
	},
}

function UpgradeConfig.max(id)
	local u = UpgradeConfig.Upgrades[id]
	return u and #u.prices or 0
end

function UpgradeConfig.price(id, currentLevel)
	local u = UpgradeConfig.Upgrades[id]
	return u and u.prices[currentLevel + 1] or nil
end

function UpgradeConfig.capacity(level)
	local u = UpgradeConfig.Upgrades.capacity
	return u.base + u.perLevel * (level or 0)
end

function UpgradeConfig.openDuration(level)
	local d = UpgradeConfig.Upgrades.speed.durations
	return d[math.clamp((level or 0) + 1, 1, #d)]
end

function UpgradeConfig.missionMultiplier(level)
	return 1 + UpgradeConfig.Upgrades.missionBonus.perLevel * (level or 0)
end

function UpgradeConfig.showcaseSlots(level)
	local u = UpgradeConfig.Upgrades.showcase
	return u.base + u.perLevel * (level or 0)
end

UpgradeConfig.MaxShowcaseSlots = UpgradeConfig.showcaseSlots(#UpgradeConfig.Upgrades.showcase.prices)

-- Texto "atual → próximo" para a loja
function UpgradeConfig.benefitText(id, level)
	if id == "capacity" then
		return UpgradeConfig.capacity(level) .. " objetos"
	elseif id == "speed" then
		return string.format("%.1f s", UpgradeConfig.openDuration(level))
	elseif id == "missionBonus" then
		return "+" .. math.floor(UpgradeConfig.Upgrades.missionBonus.perLevel * level * 100 + 0.5) .. "%"
	elseif id == "showcase" then
		return UpgradeConfig.showcaseSlots(level) .. " espaços"
	end
	return ""
end

return UpgradeConfig
