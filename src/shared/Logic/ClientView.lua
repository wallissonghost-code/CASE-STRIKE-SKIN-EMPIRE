-- ClientView: fotografia somente-leitura do perfil enviada ao cliente.
-- O cliente nunca envia valores econômicos; ele só mostra o que está aqui.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local EventConfig = require(Shared.Config.EventConfig)
local ProfileOps = require(script.Parent.ProfileOps)
local ProfileSchema = require(script.Parent.ProfileSchema)
local Income = require(script.Parent.Income)

local ClientView = {}

local function eventInfo(e)
	if not e then
		return nil
	end
	return { id = e.id, name = e.name, icon = e.icon, kind = e.kind, description = e.description, startsAt = e.startsAt, endsAt = e.endsAt }
end

-- extra = { name, baseIndex, shieldUntil, carrying = { name, speciesId, mutationId, endsAt } }
function ClientView.build(profile, now, extra)
	extra = extra or {}
	ProfileOps.refreshPeriods(profile, now)
	local creatures = {}
	for uid, c in pairs(profile.creatures) do
		table.insert(creatures, {
			uid = uid,
			speciesId = c.s,
			mutationId = c.m,
			pad = c.pad,
			rate = Income.rate(profile, c),
			value = Income.value(c),
			sellPrice = Income.sellPrice(c),
			pending = Income.pending(profile, c, now),
			cap = Income.cap(profile, c),
			origin = c.origin,
			protectedUntil = c.protectedUntil,
		})
	end
	table.sort(creatures, function(a, b)
		return a.pad < b.pad
	end)

	local missions = {}
	for _, id in ipairs(profile.missions.list) do
		local def = ProgressConfig.MissionById[id]
		if def then
			table.insert(missions, {
				id = id,
				description = def.description,
				target = def.target,
				progress = profile.missions.progress[id] or 0,
				claimed = profile.missions.claimed[id] == true,
				rewardCoins = ProfileOps.rewardCoins(profile, def.reward),
				rewardPotions = def.reward.potions,
			})
		end
	end

	local milestones = {}
	local indexCount = ProfileOps.indexCount(profile)
	for _, m in ipairs(ProgressConfig.IndexMilestones) do
		table.insert(milestones, {
			id = m.id,
			count = m.count,
			claimed = profile.milestones[m.id] == true,
			ready = indexCount >= m.count,
			rewardCoins = ProfileOps.rewardCoins(profile, m.reward),
			rewardPotions = m.reward.potions,
		})
	end

	local upgrades = {}
	for _, id in ipairs(GameConfig.UpgradeOrder) do
		local u = GameConfig.Upgrades[id]
		local level = profile.upgrades[id] or 0
		table.insert(upgrades, {
			id = id,
			name = u.name,
			description = u.description,
			level = level,
			maxLevel = u.maxLevel,
			cost = level < u.maxLevel and GameConfig.upgradeCost(id, level) or nil,
		})
	end

	local gifts = ProfileOps.giftStatus(profile, now)
	local giftRewards = {}
	for i, g in ipairs(ProgressConfig.DailyGifts) do
		giftRewards[i] = { coins = ProfileOps.rewardCoins(profile, g), potions = g.potions }
	end
	local luck, luckSources = ProfileOps.luck(profile, now)
	local index = {}
	for k in pairs(profile.index) do
		index[k] = true
	end

	return {
		serverTime = now,
		name = extra.name,
		coins = profile.coins,
		netWorth = Income.netWorth(profile),
		rate = Income.totalRate(profile),
		boost = Income.currentBoost(profile, now),
		pending = Income.totalPending(profile, now),
		storageSeconds = Income.storageSeconds(profile),
		slots = ProfileSchema.slots(profile),
		creatures = creatures,
		upgrades = upgrades,
		potions = profile.potions,
		activePotions = profile.activePotions,
		luck = luck,
		luckSources = luckSources,
		index = index,
		indexCount = indexCount,
		indexTotal = #GameConfig.Species * #GameConfig.MutationOrder,
		milestones = milestones,
		missions = missions,
		missionsResetIn = gifts.resetsIn,
		gifts = gifts,
		giftRewards = giftRewards,
		rebirths = profile.rebirths,
		rebirth = ProfileOps.rebirthInfo(profile),
		incomeMultiplier = Income.multiplier(profile),
		shieldSeconds = ProfileOps.shieldSeconds(profile),
		stats = profile.stats,
		settings = profile.settings,
		baseIndex = extra.baseIndex,
		shieldUntil = extra.shieldUntil or 0,
		carrying = extra.carrying,
		event = eventInfo(EventConfig.at(now)),
		nextEvent = eventInfo(EventConfig.nextEvent(now)),
	}
end

return ClientView
