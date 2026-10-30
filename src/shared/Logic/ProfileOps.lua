-- Todas as regras que alteram o perfil, como funções puras (sem Roblox, sem rede).
-- O servidor chama estas funções; nenhuma delas confia em valores vindos do cliente.
-- Cada operação valida TUDO antes de alterar qualquer campo, então uma recusa nunca
-- deixa o perfil pela metade. Retorno: { ok = true, ... } ou { ok = false, error, message }.

local Shared = script.Parent.Parent
local EconomyConfig = require(Shared.EconomyConfig)
local ItemDefinitions = require(Shared.ItemDefinitions)
local MachineDefinitions = require(Shared.MachineDefinitions)
local RarityConfig = require(Shared.RarityConfig)
local UpgradeConfig = require(Shared.UpgradeConfig)
local MissionDefinitions = require(Shared.MissionDefinitions)
local Levels = require(script.Parent.Levels)
local Odds = require(script.Parent.Odds)
local TimeUtil = require(Shared.Util.TimeUtil)

local ProfileOps = {}

local function fail(code, message, extra)
	local r = { ok = false, error = code, message = message }
	if extra then
		for k, v in pairs(extra) do
			r[k] = v
		end
	end
	return r
end

---------------------------------------------------------------------------
-- consultas
---------------------------------------------------------------------------
function ProfileOps.level(p)
	return Levels.level(p.xp)
end

function ProfileOps.itemCount(p)
	local n = 0
	for _, c in pairs(p.inventory) do
		n = n + c
	end
	return n
end

function ProfileOps.capacity(p)
	return UpgradeConfig.capacity(p.upgrades.capacity)
end

function ProfileOps.showcaseSlots(p)
	return UpgradeConfig.showcaseSlots(p.upgrades.showcase)
end

function ProfileOps.displayedCount(p, itemId)
	local n = 0
	for i = 1, UpgradeConfig.MaxShowcaseSlots do
		if p.showcase[i] == itemId then
			n = n + 1
		end
	end
	return n
end

-- cópias que podem ser vendidas (fora da vitrine e não favoritas)
function ProfileOps.sellable(p, itemId)
	if p.favorites[itemId] then
		return 0
	end
	return math.max(0, (p.inventory[itemId] or 0) - ProfileOps.displayedCount(p, itemId))
end

function ProfileOps.discoveredCount(p)
	local n = 0
	for _ in pairs(p.discovered) do
		n = n + 1
	end
	return n
end

function ProfileOps.collectionValue(p)
	local total = 0
	for id, c in pairs(p.inventory) do
		total = total + ItemDefinitions.get(id).value * c
	end
	return total
end

function ProfileOps.achievementCount(p)
	local n = 0
	for _ in pairs(p.achievements) do
		n = n + 1
	end
	return n
end

function ProfileOps.setProgress(p, set)
	local have, total = 0, 0
	for _, item in ipairs(ItemDefinitions.List) do
		if set.machine == nil or item.machine == set.machine then
			total = total + 1
			if p.discovered[item.id] then
				have = have + 1
			end
		end
	end
	return have, total
end

function ProfileOps.setComplete(p, set)
	local have, total = ProfileOps.setProgress(p, set)
	return have >= total
end

function ProfileOps.metric(p, name)
	if name == "opens" then
		return p.stats.opens
	elseif name == "sold" then
		return p.stats.sold
	elseif name == "discovered" then
		return ProfileOps.discoveredCount(p)
	elseif name == "level" then
		return ProfileOps.level(p)
	elseif name == "bestRank" then
		return p.stats.bestRank
	elseif name == "displayed" then
		local n = 0
		for i = 1, UpgradeConfig.MaxShowcaseSlots do
			if p.showcase[i] ~= "" then
				n = n + 1
			end
		end
		return n
	elseif name == "setsComplete" then
		local n = 0
		for _, set in ipairs(MissionDefinitions.CollectionSets) do
			if set.machine and ProfileOps.setComplete(p, set) then
				n = n + 1
			end
		end
		return n
	end
	return 0
end

-- Coins de missões/presentes: base × escala por nível × melhoria de recompensas
function ProfileOps.rewardCoins(p, base)
	return math.floor(base * EconomyConfig.levelScale(ProfileOps.level(p)) * UpgradeConfig.missionMultiplier(p.upgrades.missionBonus))
end

---------------------------------------------------------------------------
-- moedas e XP
---------------------------------------------------------------------------
function ProfileOps.addCoins(p, amount)
	amount = math.floor(amount)
	p.coins = math.clamp(p.coins + amount, 0, EconomyConfig.MaxCoins)
	if amount > 0 then
		p.stats.coinsEarned = p.stats.coinsEarned + amount
	end
end

-- Adiciona XP e paga a recompensa de cada nível novo (uma vez por nível).
-- Retorna { levels = { níveis alcançados }, coins = moedas pagas }.
function ProfileOps.addXp(p, amount)
	local before = ProfileOps.level(p)
	p.xp = p.xp + math.max(0, math.floor(amount))
	local after = ProfileOps.level(p)
	local gained = { levels = {}, coins = 0 }
	for level = before + 1, after do
		table.insert(gained.levels, level)
		if level > p.levelRewarded then
			local coins = EconomyConfig.levelReward(level)
			ProfileOps.addCoins(p, coins)
			gained.coins = gained.coins + coins
			p.levelRewarded = level
		end
	end
	return gained
end

---------------------------------------------------------------------------
-- missões diárias
---------------------------------------------------------------------------
-- Escolhe as missões do dia: 1 gratuita (alterna por dia) + sorteio determinístico do restante.
function ProfileOps.dailySelection(p, day)
	local free = MissionDefinitions.DailyFree
	local chosen = { free[(day % #free) + 1].id }
	local allFound = ProfileOps.discoveredCount(p) >= ItemDefinitions.count()
	local candidates = {}
	for _, def in ipairs(MissionDefinitions.DailyPool) do
		if not (def.needsUndiscovered and allFound) then
			table.insert(candidates, def.id)
		end
	end
	-- gerador congruente simples com o dia como semente (igual em todos os servidores)
	local seed = (day * 7919 + 104729) % 2147483647
	while #chosen < MissionDefinitions.DailyCount and #candidates > 0 do
		seed = (seed * 16807) % 2147483647
		local i = (seed % #candidates) + 1
		table.insert(chosen, table.remove(candidates, i))
	end
	return chosen
end

function ProfileOps.ensureDaily(p, now)
	local day = TimeUtil.day(now)
	if p.daily.day == day then
		return false
	end
	local missions = {}
	for _, id in ipairs(ProfileOps.dailySelection(p, day)) do
		table.insert(missions, { id = id, progress = 0, claimed = false })
	end
	p.daily = { day = day, missions = missions, openXp = 0 }
	return true
end

-- Registra uma ação para as missões do dia. Retorna true se alguma missão avançou.
function ProfileOps.track(p, event, amount, now)
	ProfileOps.ensureDaily(p, now)
	local changed = false
	for _, m in ipairs(p.daily.missions) do
		local def = MissionDefinitions.DailyById[m.id]
		if def.event == event and not m.claimed and m.progress < def.target then
			m.progress = math.min(def.target, m.progress + (amount or 1))
			changed = true
		end
	end
	return changed
end

function ProfileOps.claimDaily(p, missionId, now)
	ProfileOps.ensureDaily(p, now)
	for _, m in ipairs(p.daily.missions) do
		if m.id == missionId then
			local def = MissionDefinitions.DailyById[m.id]
			if m.claimed then
				return fail("claimed", "Missão já resgatada hoje.")
			end
			if m.progress < def.target then
				return fail("incomplete", "Missão ainda não concluída.")
			end
			local coins = ProfileOps.rewardCoins(p, def.coins)
			m.claimed = true
			ProfileOps.addCoins(p, coins)
			local gained = ProfileOps.addXp(p, def.xp)
			return { ok = true, coins = coins, xp = def.xp, levels = gained.levels, levelCoins = gained.coins }
		end
	end
	return fail("unknown", "Missão não encontrada.")
end

---------------------------------------------------------------------------
-- máquinas
---------------------------------------------------------------------------
function ProfileOps.canUseMachine(p, machineId)
	local machine = MachineDefinitions.get(machineId)
	if not machine then
		return fail("unknown", "Máquina desconhecida.")
	end
	if ProfileOps.level(p) < machine.level then
		return fail("locked", "Disponível no nível " .. machine.level .. ".")
	end
	if p.coins < machine.price then
		return fail("coins", "Coins insuficientes. Venda objetos, faça missões ou colete moedas no parque.")
	end
	if ProfileOps.itemCount(p) >= ProfileOps.capacity(p) then
		return fail("full", "Inventário cheio. Venda objetos ou compre mais capacidade.")
	end
	return { ok = true, machine = machine }
end

-- r: número aleatório do SERVIDOR em [0, 1). Cobra, sorteia, entrega e registra tudo de uma vez.
function ProfileOps.useMachine(p, machineId, r, now)
	local check = ProfileOps.canUseMachine(p, machineId)
	if not check.ok then
		return check
	end
	local machine = check.machine
	local itemId = Odds.pick(machine, r)
	local item = ItemDefinitions.get(itemId)
	local rarity = RarityConfig.get(item.rarity)

	p.coins = p.coins - machine.price
	p.inventory[itemId] = (p.inventory[itemId] or 0) + 1
	p.stats.opens = p.stats.opens + 1
	p.stats.bestRank = math.max(p.stats.bestRank, rarity.rank)

	ProfileOps.ensureDaily(p, now)
	local isNew = p.discovered[itemId] == nil
	local xp = 0
	if isNew then
		p.discovered[itemId] = now
		xp = xp + rarity.xp
		ProfileOps.track(p, "discover", 1, now)
	end
	local openXp = math.min(EconomyConfig.OpenXp, EconomyConfig.OpenXpDailyCap - p.daily.openXp)
	if openXp > 0 then
		p.daily.openXp = p.daily.openXp + openXp
		xp = xp + openXp
	end
	ProfileOps.track(p, "open", 1, now)
	local gained = ProfileOps.addXp(p, xp)

	return {
		ok = true,
		machineId = machineId,
		itemId = itemId,
		rarity = item.rarity,
		value = item.value,
		isNew = isNew,
		xp = xp,
		price = machine.price,
		levels = gained.levels,
		levelCoins = gained.coins,
		duration = UpgradeConfig.openDuration(p.upgrades.speed),
	}
end

---------------------------------------------------------------------------
-- inventário
---------------------------------------------------------------------------
function ProfileOps.sell(p, itemId, amount, confirmed, now)
	local item = ItemDefinitions.get(itemId)
	if not item or (p.inventory[itemId] or 0) <= 0 then
		return fail("missing", "Você não possui este objeto.")
	end
	if type(amount) ~= "number" or amount ~= amount or amount < 1 or amount ~= math.floor(amount) then
		return fail("amount", "Quantidade inválida.")
	end
	if p.favorites[itemId] then
		return fail("favorite", "Objeto favorito: desfavorite para vender.")
	end
	local available = ProfileOps.sellable(p, itemId)
	if available <= 0 then
		return fail("displayed", "Todas as cópias estão na vitrine.")
	end
	if amount > available then
		return fail("amount", "Você só pode vender " .. available .. ".")
	end
	if RarityConfig.get(item.rarity).confirmSale and confirmed ~= true then
		return fail("confirm", "Confirme a venda de " .. item.name .. ".", { needsConfirm = true })
	end
	local coins = item.value * amount
	p.inventory[itemId] = p.inventory[itemId] - amount
	if p.inventory[itemId] <= 0 then
		p.inventory[itemId] = nil
	end
	ProfileOps.addCoins(p, coins)
	p.stats.sold = p.stats.sold + amount
	ProfileOps.track(p, "sell", amount, now)
	if item.rarity == "common" then
		ProfileOps.track(p, "sell_common", amount, now)
	end
	return { ok = true, coins = coins, amount = amount, itemId = itemId }
end

-- Vende as cópias extras (mantém 1) das raridades de EconomyConfig.DuplicateSellRarities.
-- Favoritos e itens expostos ficam protegidos.
function ProfileOps.sellDuplicates(p, now)
	local plan = {}
	for _, item in ipairs(ItemDefinitions.List) do
		if EconomyConfig.DuplicateSellRarities[item.rarity] then
			local count = p.inventory[item.id] or 0
			local extra = math.min(count - 1, ProfileOps.sellable(p, item.id))
			if extra > 0 then
				table.insert(plan, { item = item, amount = extra })
			end
		end
	end
	if #plan == 0 then
		return fail("none", "Nenhum repetido Comum ou Incomum para vender.")
	end
	local coins, amount, commons = 0, 0, 0
	for _, entry in ipairs(plan) do
		p.inventory[entry.item.id] = p.inventory[entry.item.id] - entry.amount
		coins = coins + entry.item.value * entry.amount
		amount = amount + entry.amount
		if entry.item.rarity == "common" then
			commons = commons + entry.amount
		end
	end
	ProfileOps.addCoins(p, coins)
	p.stats.sold = p.stats.sold + amount
	ProfileOps.track(p, "sell", amount, now)
	if commons > 0 then
		ProfileOps.track(p, "sell_common", commons, now)
	end
	return { ok = true, coins = coins, amount = amount }
end

function ProfileOps.setFavorite(p, itemId, value)
	if not ItemDefinitions.get(itemId) or (p.inventory[itemId] or 0) <= 0 then
		return fail("missing", "Você não possui este objeto.")
	end
	p.favorites[itemId] = value == true or nil
	return { ok = true, favorite = p.favorites[itemId] == true }
end

function ProfileOps.display(p, itemId, slot, now)
	local item = ItemDefinitions.get(itemId)
	if not item or (p.inventory[itemId] or 0) <= 0 then
		return fail("missing", "Você não possui este objeto.")
	end
	local slots = ProfileOps.showcaseSlots(p)
	if slot == nil then
		for i = 1, slots do
			if p.showcase[i] == "" then
				slot = i
				break
			end
		end
		if slot == nil then
			return fail("full", "Todas as vitrines estão ocupadas. Retire um objeto ou compre mais vitrines.")
		end
	end
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > slots then
		return fail("slot", "Vitrine inválida.")
	end
	if p.showcase[slot] == itemId then
		return { ok = true, slot = slot }
	end
	-- o objeto que já estava no espaço volta a ficar livre, então só conta o que fica exposto
	if ProfileOps.displayedCount(p, itemId) >= p.inventory[itemId] then
		return fail("noCopy", "Todas as suas cópias já estão expostas.")
	end
	p.showcase[slot] = itemId
	ProfileOps.track(p, "display", 1, now)
	return { ok = true, slot = slot }
end

function ProfileOps.undisplay(p, slot)
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > UpgradeConfig.MaxShowcaseSlots then
		return fail("slot", "Vitrine inválida.")
	end
	if p.showcase[slot] == "" then
		return fail("empty", "Esta vitrine já está vazia.")
	end
	p.showcase[slot] = ""
	return { ok = true }
end

---------------------------------------------------------------------------
-- melhorias
---------------------------------------------------------------------------
function ProfileOps.buyUpgrade(p, upgradeId)
	if not UpgradeConfig.Upgrades[upgradeId] then
		return fail("unknown", "Melhoria desconhecida.")
	end
	local level = p.upgrades[upgradeId]
	if level >= UpgradeConfig.max(upgradeId) then
		return fail("max", "Melhoria já está no nível máximo.")
	end
	local price = UpgradeConfig.price(upgradeId, level)
	if p.coins < price then
		return fail("coins", "Coins insuficientes.")
	end
	p.coins = p.coins - price
	p.upgrades[upgradeId] = level + 1
	return { ok = true, level = level + 1, price = price }
end

---------------------------------------------------------------------------
-- conquistas, coleção, títulos
---------------------------------------------------------------------------
function ProfileOps.claimAchievement(p, id)
	local def = MissionDefinitions.AchievementById[id]
	if not def then
		return fail("unknown", "Conquista desconhecida.")
	end
	if p.achievements[id] then
		return fail("claimed", "Conquista já resgatada.")
	end
	if ProfileOps.metric(p, def.metric) < def.target then
		return fail("incomplete", "Conquista ainda não alcançada.")
	end
	p.achievements[id] = true
	ProfileOps.addCoins(p, def.coins)
	if def.title then
		p.titles[def.title] = true
	end
	local gained = ProfileOps.addXp(p, def.xp)
	return { ok = true, coins = def.coins, xp = def.xp, title = def.title, levels = gained.levels, levelCoins = gained.coins }
end

function ProfileOps.claimSet(p, setId)
	local set = MissionDefinitions.SetById[setId]
	if not set then
		return fail("unknown", "Coleção desconhecida.")
	end
	if p.sets[setId] then
		return fail("claimed", "Recompensa já resgatada.")
	end
	if not ProfileOps.setComplete(p, set) then
		return fail("incomplete", "Coleção incompleta.")
	end
	p.sets[setId] = true
	ProfileOps.addCoins(p, set.coins)
	if set.title then
		p.titles[set.title] = true
	end
	local gained = ProfileOps.addXp(p, set.xp)
	return { ok = true, coins = set.coins, xp = set.xp, title = set.title, levels = gained.levels, levelCoins = gained.coins }
end

function ProfileOps.setTitle(p, titleId)
	if titleId == "" or titleId == nil then
		p.title = ""
		return { ok = true }
	end
	if type(titleId) ~= "string" or not p.titles[titleId] then
		return fail("locked", "Título ainda não desbloqueado.")
	end
	p.title = titleId
	return { ok = true }
end

---------------------------------------------------------------------------
-- presente diário, moedas perdidas, tempo de jogo, configurações
---------------------------------------------------------------------------
function ProfileOps.giftStatus(p, now)
	local day = TimeUtil.day(now)
	local streak = p.gift.streak
	if p.gift.lastDay ~= day - 1 and p.gift.lastDay ~= day then
		streak = 0
	end
	local nextStreak = (streak % #EconomyConfig.DailyGift.coins) + 1
	return {
		canClaim = p.gift.lastDay ~= day,
		streak = streak,
		nextStreak = nextStreak,
		coins = ProfileOps.rewardCoins(p, EconomyConfig.DailyGift.coins[nextStreak]),
		xp = EconomyConfig.DailyGift.xp,
		secondsLeft = TimeUtil.secondsToNextDay(now),
	}
end

function ProfileOps.claimGift(p, now)
	local status = ProfileOps.giftStatus(p, now)
	if not status.canClaim then
		return fail("claimed", "Presente de hoje já resgatado.")
	end
	p.gift.lastDay = TimeUtil.day(now)
	p.gift.streak = status.nextStreak
	ProfileOps.addCoins(p, status.coins)
	local gained = ProfileOps.addXp(p, status.xp)
	return { ok = true, coins = status.coins, xp = status.xp, streak = status.nextStreak, levels = gained.levels, levelCoins = gained.coins }
end

function ProfileOps.pickupsLeft(p, now)
	if p.pickups.hour ~= TimeUtil.hour(now) then
		return EconomyConfig.Pickups.hourlyLimit
	end
	return math.max(0, EconomyConfig.Pickups.hourlyLimit - p.pickups.count)
end

function ProfileOps.pickup(p, now)
	if ProfileOps.pickupsLeft(p, now) <= 0 then
		return fail("limit", "Você já coletou todas as moedas desta hora.")
	end
	local hour = TimeUtil.hour(now)
	if p.pickups.hour ~= hour then
		p.pickups.hour = hour
		p.pickups.count = 0
	end
	p.pickups.count = p.pickups.count + 1
	local coins = EconomyConfig.pickupValue(ProfileOps.level(p))
	ProfileOps.addCoins(p, coins)
	ProfileOps.track(p, "pickup", 1, now)
	return { ok = true, coins = coins }
end

function ProfileOps.addPlaytime(p, seconds, now)
	return ProfileOps.track(p, "playtime", math.max(0, math.floor(seconds)), now)
end

function ProfileOps.setSetting(p, key, value)
	if type(key) ~= "string" or p.settings[key] == nil or type(value) ~= type(p.settings[key]) then
		return fail("invalid", "Configuração inválida.")
	end
	p.settings[key] = value
	return { ok = true }
end

return ProfileOps
