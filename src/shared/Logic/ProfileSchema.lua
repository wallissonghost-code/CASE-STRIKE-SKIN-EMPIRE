-- Formato do perfil salvo e reparo de dados antigos/corrompidos.
-- Inventário em pilhas: inventory[itemId] = quantidade. Itens expostos continuam no inventário
-- e ficam reservados (não podem ser vendidos), por isso a vitrine nunca duplica objetos.

local Shared = script.Parent.Parent
local EconomyConfig = require(Shared.EconomyConfig)
local ItemDefinitions = require(Shared.ItemDefinitions)
local UpgradeConfig = require(Shared.UpgradeConfig)
local MissionDefinitions = require(Shared.MissionDefinitions)

local ProfileSchema = {}

ProfileSchema.Version = 1

function ProfileSchema.new()
	local showcase = {}
	for i = 1, UpgradeConfig.MaxShowcaseSlots do
		showcase[i] = ""
	end
	return {
		version = ProfileSchema.Version,
		coins = EconomyConfig.StartingCoins,
		xp = 0,
		levelRewarded = 1,
		inventory = {},
		favorites = {},
		discovered = {},
		showcase = showcase,
		upgrades = { capacity = 0, speed = 0, missionBonus = 0, showcase = 0 },
		stats = { opens = 0, sold = 0, coinsEarned = 0, bestRank = 0 },
		daily = { day = -1, missions = {}, openXp = 0 },
		achievements = {},
		sets = {},
		titles = {},
		title = "",
		gift = { lastDay = -1, streak = 0 },
		pickups = { hour = -1, count = 0 },
		settings = { autoSkip = false, sound = true, effects = true },
	}
end

local function num(v, default, min, max)
	v = tonumber(v)
	if v == nil or v ~= v then
		return default
	end
	if min and v < min then
		v = min
	end
	if max and v > max then
		v = max
	end
	return v
end

local function int(v, default, min, max)
	return math.floor(num(v, default, min, max))
end

-- Corrige o perfil no lugar e retorna a lista de correções feitas (vazia se estava íntegro).
function ProfileSchema.reconcile(p)
	local fixes = {}
	local default = ProfileSchema.new()
	if type(p) ~= "table" then
		return default, { "perfil inválido substituído" }
	end
	local function tableField(key)
		if type(p[key]) ~= "table" then
			p[key] = default[key]
			table.insert(fixes, key)
		end
	end
	for _, key in ipairs({ "inventory", "favorites", "discovered", "showcase", "upgrades", "stats", "daily", "achievements", "sets", "titles", "gift", "pickups", "settings" }) do
		tableField(key)
	end

	local coins = int(p.coins, EconomyConfig.StartingCoins, 0, EconomyConfig.MaxCoins)
	if coins ~= p.coins then
		table.insert(fixes, "coins")
	end
	p.coins = coins
	p.xp = int(p.xp, 0, 0)
	p.levelRewarded = int(p.levelRewarded, 1, 1)
	p.version = ProfileSchema.Version

	-- inventário: só ids conhecidos e quantidades inteiras positivas
	for id, count in pairs(p.inventory) do
		local n = int(count, 0, 0)
		if not ItemDefinitions.get(id) or n <= 0 then
			p.inventory[id] = nil
			table.insert(fixes, "inventory." .. tostring(id))
		elseif n ~= count then
			p.inventory[id] = n
			table.insert(fixes, "inventory." .. tostring(id))
		end
	end
	for id, v in pairs(p.favorites) do
		if not ItemDefinitions.get(id) or v ~= true then
			p.favorites[id] = nil
		end
	end
	for id, v in pairs(p.discovered) do
		if not ItemDefinitions.get(id) then
			p.discovered[id] = nil
		elseif type(v) ~= "number" then
			p.discovered[id] = 0
		end
	end
	-- todo objeto possuído conta como descoberto
	for id in pairs(p.inventory) do
		if not p.discovered[id] then
			p.discovered[id] = 0
		end
	end

	-- vitrine: lista fixa; nenhum objeto exposto além da quantidade possuída
	local showcase = {}
	local used = {}
	for i = 1, UpgradeConfig.MaxShowcaseSlots do
		local id = p.showcase[i]
		if type(id) == "string" and id ~= "" and ItemDefinitions.get(id) and (used[id] or 0) < (p.inventory[id] or 0) then
			used[id] = (used[id] or 0) + 1
			showcase[i] = id
		else
			if id ~= nil and id ~= "" then
				table.insert(fixes, "showcase." .. i)
			end
			showcase[i] = ""
		end
	end
	p.showcase = showcase

	for _, id in ipairs(UpgradeConfig.Order) do
		p.upgrades[id] = int(p.upgrades[id], 0, 0, UpgradeConfig.max(id))
	end
	for key in pairs(p.upgrades) do
		if not UpgradeConfig.Upgrades[key] then
			p.upgrades[key] = nil
		end
	end
	-- vitrines que deixaram de existir (nível de melhoria menor) são esvaziadas
	local slots = UpgradeConfig.showcaseSlots(p.upgrades.showcase)
	for i = slots + 1, UpgradeConfig.MaxShowcaseSlots do
		p.showcase[i] = ""
	end

	local s = p.stats
	s.opens = int(s.opens, 0, 0)
	s.sold = int(s.sold, 0, 0)
	s.coinsEarned = int(s.coinsEarned, 0, 0)
	s.bestRank = int(s.bestRank, 0, 0, 6)

	local d = p.daily
	d.day = int(d.day, -1)
	d.openXp = int(d.openXp, 0, 0)
	if type(d.missions) ~= "table" then
		d.missions = {}
		d.day = -1
	end
	for i = #d.missions, 1, -1 do
		local m = d.missions[i]
		if type(m) ~= "table" or not MissionDefinitions.DailyById[m.id] then
			table.remove(d.missions, i)
			d.day = -1 -- refaz as missões do dia
		else
			m.progress = int(m.progress, 0, 0)
			m.claimed = m.claimed == true
		end
	end

	for id, v in pairs(p.achievements) do
		if not MissionDefinitions.AchievementById[id] or v ~= true then
			p.achievements[id] = nil
		end
	end
	for id, v in pairs(p.sets) do
		if not MissionDefinitions.SetById[id] or v ~= true then
			p.sets[id] = nil
		end
	end
	for id, v in pairs(p.titles) do
		if not MissionDefinitions.Titles[id] or v ~= true then
			p.titles[id] = nil
		end
	end
	if type(p.title) ~= "string" or (p.title ~= "" and not p.titles[p.title]) then
		p.title = ""
	end

	p.gift.lastDay = int(p.gift.lastDay, -1)
	p.gift.streak = int(p.gift.streak, 0, 0, #EconomyConfig.DailyGift.coins)
	p.pickups.hour = int(p.pickups.hour, -1)
	p.pickups.count = int(p.pickups.count, 0, 0)

	for key, value in pairs(default.settings) do
		if type(p.settings[key]) ~= type(value) then
			p.settings[key] = value
		end
	end
	for key in pairs(p.settings) do
		if default.settings[key] == nil then
			p.settings[key] = nil
		end
	end
	return p, fixes
end

function ProfileSchema.deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in pairs(v) do
		out[k] = ProfileSchema.deepCopy(x)
	end
	return out
end

return ProfileSchema
