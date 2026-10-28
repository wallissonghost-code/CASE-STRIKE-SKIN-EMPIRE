-- Progression: XP, níveis e limites diários de XP repetitivo.

local Shared = script.Parent.Parent
local ProgressionConfig = require(Shared.Config.ProgressionConfig)
local TimeUtil = require(Shared.Util.TimeUtil)

local Progression = {}

function Progression.xpNeeded(level)
	return ProgressionConfig.xpForLevel(level)
end

-- Adiciona XP respeitando limites diários das fontes repetitivas.
-- Retorna (xpConcedido, niveisGanhos)
function Progression.addXp(profile, amount, source, now)
	amount = math.floor(amount or 0)
	if amount <= 0 then
		return 0, 0
	end
	local cap = ProgressionConfig.DailyXpCaps[source]
	if cap then
		local day = TimeUtil.dayIndex(now)
		local caps = profile.xpCaps
		if caps.day ~= day then
			caps.day = day
			caps.bySource = {}
		end
		local used = caps.bySource[source] or 0
		local allowed = math.max(0, cap - used)
		amount = math.min(amount, allowed)
		caps.bySource[source] = used + amount
		if amount <= 0 then
			return 0, 0
		end
	end

	local gained = 0
	if profile.level >= ProgressionConfig.MaxLevel then
		return 0, 0
	end
	profile.xp = profile.xp + amount
	while profile.level < ProgressionConfig.MaxLevel and profile.xp >= Progression.xpNeeded(profile.level) do
		profile.xp = profile.xp - Progression.xpNeeded(profile.level)
		profile.level = profile.level + 1
		gained = gained + 1
	end
	if profile.level >= ProgressionConfig.MaxLevel then
		profile.xp = 0
	end
	return amount, gained
end

return Progression
