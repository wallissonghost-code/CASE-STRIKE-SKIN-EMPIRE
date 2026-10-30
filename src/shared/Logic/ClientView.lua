-- "Fotografia" do perfil enviada ao cliente (DataUpdated). Contém só o que a interface exibe,
-- já com valores calculados no servidor (nível, capacidade, missões, presentes...).

local Shared = script.Parent.Parent
local ItemDefinitions = require(Shared.ItemDefinitions)
local UpgradeConfig = require(Shared.UpgradeConfig)
local MissionDefinitions = require(Shared.MissionDefinitions)
local Levels = require(script.Parent.Levels)
local ProfileOps = require(script.Parent.ProfileOps)

local ClientView = {}

function ClientView.build(p, now)
	ProfileOps.ensureDaily(p, now)
	local level, into, needed = Levels.fromXp(p.xp)

	local daily = {}
	for _, m in ipairs(p.daily.missions) do
		local def = MissionDefinitions.DailyById[m.id]
		table.insert(daily, {
			id = m.id,
			text = def.text,
			progress = m.progress,
			target = def.target,
			claimed = m.claimed,
			coins = ProfileOps.rewardCoins(p, def.coins),
			xp = def.xp,
		})
	end

	local achievements = {}
	for _, def in ipairs(MissionDefinitions.Achievements) do
		table.insert(achievements, {
			id = def.id,
			text = def.text,
			progress = math.min(def.target, ProfileOps.metric(p, def.metric)),
			target = def.target,
			claimed = p.achievements[def.id] == true,
			coins = def.coins,
			xp = def.xp,
		})
	end

	local sets = {}
	for _, set in ipairs(MissionDefinitions.CollectionSets) do
		local have, total = ProfileOps.setProgress(p, set)
		table.insert(sets, { id = set.id, have = have, total = total, claimed = p.sets[set.id] == true })
	end

	local displayed = {}
	for id in pairs(p.inventory) do
		displayed[id] = ProfileOps.displayedCount(p, id)
	end

	local upgrades = {}
	for _, id in ipairs(UpgradeConfig.Order) do
		upgrades[id] = p.upgrades[id]
	end

	return {
		coins = p.coins,
		xp = p.xp,
		level = level,
		xpInto = into,
		xpNeeded = needed,
		inventory = p.inventory,
		favorites = p.favorites,
		displayed = displayed,
		discovered = p.discovered,
		discoveredCount = ProfileOps.discoveredCount(p),
		totalItems = ItemDefinitions.count(),
		showcase = p.showcase,
		showcaseSlots = ProfileOps.showcaseSlots(p),
		itemCount = ProfileOps.itemCount(p),
		capacity = ProfileOps.capacity(p),
		collectionValue = ProfileOps.collectionValue(p),
		upgrades = upgrades,
		openDuration = UpgradeConfig.openDuration(p.upgrades.speed),
		daily = daily,
		achievements = achievements,
		sets = sets,
		gift = ProfileOps.giftStatus(p, now),
		titles = p.titles,
		title = p.title,
		settings = p.settings,
		stats = p.stats,
		pickupsLeft = ProfileOps.pickupsLeft(p, now),
	}
end

return ClientView
