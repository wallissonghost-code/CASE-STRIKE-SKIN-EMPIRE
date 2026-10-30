-- Curva de níveis de colecionador. O perfil guarda só o XP total; o nível é calculado.

local EconomyConfig = require(script.Parent.Parent.EconomyConfig)

local Levels = {}

function Levels.xpToNext(level)
	return EconomyConfig.Levels.Base + EconomyConfig.Levels.PerLevel * (level - 1)
end

-- XP total necessário para ESTAR no nível `level`
function Levels.totalFor(level)
	local total = 0
	for l = 1, level - 1 do
		total = total + Levels.xpToNext(l)
	end
	return total
end

-- retorna nível, XP dentro do nível e XP necessário para o próximo
function Levels.fromXp(xp)
	xp = math.max(0, math.floor(tonumber(xp) or 0))
	local level = 1
	local maxLevel = EconomyConfig.Levels.MaxLevel
	while level < maxLevel and xp >= Levels.xpToNext(level) do
		xp = xp - Levels.xpToNext(level)
		level = level + 1
	end
	if level >= maxLevel then
		return maxLevel, 0, 0
	end
	return level, xp, Levels.xpToNext(level)
end

function Levels.level(xp)
	local level = Levels.fromXp(xp)
	return level
end

return Levels
