-- ClientView: monta a "fotografia" do perfil enviada ao cliente.
-- Contém apenas dados de exibição; o cliente nunca envia isto de volta.

local Shared = script.Parent.Parent
local BankConfig = require(Shared.Config.BankConfig)
local ProgressionConfig = require(Shared.Config.ProgressionConfig)
local MissionDefinitions = require(Shared.Config.MissionDefinitions)
local EventDefinitions = require(Shared.Config.EventDefinitions)
local AchievementDefinitions = require(Shared.Config.AchievementDefinitions)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local AttributeConfig = require(Shared.Config.AttributeConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local PotionConfig = require(Shared.Config.PotionConfig)
local CaseDefinitions = require(Shared.Config.CaseDefinitions)
local BankMath = require(Shared.Logic.BankMath)
local Wealth = require(Shared.Logic.Wealth)
local Progression = require(Shared.Logic.Progression)
local ProfileOps = require(Shared.Logic.ProfileOps)
local ProfileSchema = require(Shared.Logic.ProfileSchema)
local TimeUtil = require(Shared.Util.TimeUtil)

local ClientView = {}

local function copyMap(t)
	local out = {}
	for k, v in pairs(t or {}) do
		out[k] = v
	end
	return out
end

function ClientView.build(profile, now, playerName, zoneId)
	ProfileOps.refreshPeriods(profile, now)
	BankMath.settle(profile, now)

	local wealth = Wealth.compute(profile)

	local items = {}
	for uid, item in pairs(profile.inventory) do
		table.insert(items, {
			uid = uid,
			defId = item.defId,
			favorite = item.favorite,
			equipped = item.equipped,
			location = item.location,
			obtainedAt = item.obtainedAt,
			upgrades = copyMap(item.upgrades),
			showcase = item.showcase == true,
			income = item.location == "bank" and BankMath.itemIncome(profile, item) or 0,
		})
	end

	local upgrades = {}
	for _, id in ipairs(BankConfig.UpgradeOrder) do
		local u = BankConfig.Upgrades[id]
		local lvl = BankMath.upgradeLevel(profile, id)
		table.insert(upgrades, {
			id = id,
			displayName = u.displayName,
			description = u.description,
			level = lvl,
			maxLevel = u.maxLevel,
			cost = lvl < u.maxLevel and BankMath.upgradeCost(id, lvl) or nil,
			requiredLevel = lvl < u.maxLevel and u.requiredLevel(lvl) or nil,
		})
	end

	local attributes = {}
	for _, id in ipairs(AttributeConfig.Order) do
		table.insert(attributes, ProfileOps.attributeInfo(profile, id))
	end

	local function missionList(ids)
		local out = {}
		for _, id in ipairs(ids) do
			local def = MissionDefinitions.ById[id]
			if def then
				table.insert(out, {
					id = id,
					description = def.description,
					target = def.target,
					progress = profile.missions.progress[id] or 0,
					claimed = profile.missions.claimed[id] == true,
					reward = def.reward,
				})
			end
		end
		return out
	end

	local ev = EventDefinitions.activeEvent(now)
	local eventView = nil
	if ev then
		local challenges = {}
		for _, c in ipairs(ev.challenges) do
			table.insert(challenges, {
				id = c.id,
				description = c.description,
				target = c.target,
				progress = profile.eventProgress.progress[c.id] or 0,
				claimed = profile.eventProgress.claimed[c.id] == true,
				reward = c.reward,
			})
		end
		eventView = {
			id = ev.id,
			name = ev.name,
			description = ev.description,
			startsAt = ev.startsAt,
			endsAt = ev.endsAt,
			featuredCollection = ev.featuredCollection,
			challenges = challenges,
		}
	end
	local nextEv = EventDefinitions.nextEvent(now)

	local luckTotal, luckList = ProfileOps.activeLuck(profile, now, zoneId)

	local zones = {}
	for _, z in ipairs(ZoneConfig.Zones) do
		table.insert(zones, {
			id = z.id,
			name = z.name,
			cost = z.cost,
			luck = z.luck,
			requiredLevel = z.requiredLevel,
			requires = z.requires,
			owned = profile.zones[z.id] == true,
		})
	end

	local potions = {}
	for _, id in ipairs(PotionConfig.Order) do
		local def = PotionConfig.Potions[id]
		table.insert(potions, {
			id = id,
			displayName = def.displayName,
			icon = def.icon,
			description = def.description,
			count = profile.potions[id] or 0,
			endsAt = profile.activePotions[id] or 0,
			duration = def.duration,
			maxStack = def.maxStack,
		})
	end

	local stock = {}
	for _, c in ipairs(CaseDefinitions.List) do
		if c.stockPerDay then
			stock[c.id] = ProfileOps.stockLeft(profile, c, now)
		end
	end
	local flash = EventDefinitions.flashAt(now)
	local nextFlash = EventDefinitions.nextFlash(now)

	local achievements = {}
	for _, a in ipairs(AchievementDefinitions.List) do
		table.insert(achievements, {
			id = a.id,
			unlocked = profile.achievements[a.id] ~= nil,
			claimed = profile.achievementsClaimed[a.id] == true,
			progress = math.min(a.target, ProfileOps.statValue(profile, a.stat)),
		})
	end

	local levelRewards = {}
	for level, _ in pairs(ProgressionConfig.LevelRewards) do
		table.insert(levelRewards, {
			level = level,
			claimed = profile.rewards.levelClaimed[tostring(level)] == true,
			available = profile.level >= level,
		})
	end
	table.sort(levelRewards, function(a, b)
		return a.level < b.level
	end)

	return {
		serverTime = now,
		playerName = playerName,
		credits = profile.credits,
		level = profile.level,
		xp = profile.xp,
		xpNeeded = Progression.xpNeeded(profile.level),
		maxLevel = ProgressionConfig.MaxLevel,
		rebirths = profile.rebirths,
		wealth = wealth,
		items = items,
		inventoryCapacity = EconomyConfig.InventoryCapacity,
		equipSlots = ProfileSchema.equipSlots(profile),
		showcaseSlots = EconomyConfig.ShowcaseSlots,
		attributes = attributes,
		maxQuantity = AttributeConfig.maxQuantity(profile.attributes.multiOpen),
		speedFactor = AttributeConfig.speedFactor(profile.attributes.openSpeed),
		cosmetics = copyMap(profile.cosmetics),
		zone = zoneId or "zone1",
		zones = zones,
		potions = potions,
		stock = stock,
		stockResetsIn = TimeUtil.secondsUntilNextDay(now),
		flash = flash,
		nextFlash = nextFlash,
		materials = copyMap(profile.materials),
		freeCases = copyMap(profile.freeCases),
		bank = {
			slots = BankMath.slots(profile),
			pending = profile.bank.pending,
			storageCap = BankMath.storageCap(profile),
			rate = BankMath.totalRate(profile) * BankMath.currentBoost(profile, now),
			boost = BankMath.currentBoost(profile, now),
			efficiency = BankMath.efficiency(profile),
			maxOfflineSeconds = BankMath.offlineCap(profile),
			maxSlotsShown = BankConfig.MaxSlotsShown,
			upgrades = upgrades,
		},
		discovered = copyMap(profile.discovered),
		collections = ProfileOps.collectionStatus(profile),
		featuredCollection = ProfileOps.featuredCollection(now),
		missions = {
			daily = missionList(profile.missions.daily),
			weekly = missionList(profile.missions.weekly),
		},
		event = eventView,
		nextEvent = nextEv and { id = nextEv.id, name = nextEv.name, startsAt = nextEv.startsAt } or nil,
		daily = ProfileOps.dailyStatus(profile, now),
		levelRewards = levelRewards,
		achievements = achievements,
		luck = { total = luckTotal, sources = luckList },
		titles = copyMap(profile.titles),
		equippedTitle = profile.equippedTitle,
		rebirth = ProfileOps.rebirthPreview(profile, now),
		stats = copyMap(profile.stats),
		settings = copyMap(profile.settings),
	}
end

return ClientView
