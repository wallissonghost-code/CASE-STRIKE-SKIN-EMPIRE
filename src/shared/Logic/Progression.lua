-- Progression: XP, níveis e limites diários de XP repetitivo.

local Shared = script.Parent.Parent
local ProgressionConfig = require(Shared.Config.ProgressionConfig)
local AttributeConfig = require(Shared.Config.AttributeConfig)
local EventDefinitions = require(Shared.Config.EventDefinitions)
local PotionConfig = require(Shared.Config.PotionConfig)
local TimeUtil = require(Shared.Util.TimeUtil)

local Progression = {}

function Progression.xpNeeded(level)
	return ProgressionConfig.xpForLevel(level)
end

-- multiplicador de XP: atributo "Bônus de XP" + bônus moderado de renascimento
-- (+ poção de XP e evento relâmpago "2X XP", multiplicativos)
function Progression.xpMultiplier(profile, now)
	local attr = (profile.attributes and profile.attributes.xpBonus) or 0
	local R = ProgressionConfig.Rebirth
	local rb = math.min((profile.rebirths or 0) * R.XpBonusPerRebirth, R.XpBonusMax)
	local mult = 1 + attr * AttributeConfig.Attributes.xpBonus.perLevel + rb
	if now then
		if profile.activePotions and (profile.activePotions.xp or 0) > now then
			mult = mult * PotionConfig.Potions.xp.xpMultiplier
		end
		local flash = EventDefinitions.flashAt(now)
		if flash and flash.kind == "xp" then
			mult = mult * flash.multiplier
		end
	end
	return mult
end

-- Adiciona XP (com multiplicador) respeitando limites diários das fontes repetitivas.
-- Retorna (xpConcedido, niveisGanhos)
function Progression.addXp(profile, amount, source, now)
	amount = math.floor((amount or 0) * Progression.xpMultiplier(profile, now) + 0.5)
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
