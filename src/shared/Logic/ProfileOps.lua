-- ProfileOps: TODAS as operações que alteram o perfil.
-- Regra: valida tudo antes de alterar qualquer coisa; nenhuma função espera (yield).
-- Retornam (true, dados) ou (false, códigoDeErro). Sorteios usam ctx.rng (servidor).
--
-- ctx = { now = horárioDoServidor, rng = function() -> [0,1), locked = { [uid] = true } }
-- `locked` marca criaturas que estão sendo carregadas por um ladrão neste momento.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local EventConfig = require(Shared.Config.EventConfig)
local ProfileSchema = require(script.Parent.ProfileSchema)
local Income = require(script.Parent.Income)
local Odds = require(script.Parent.Odds)
local TimeUtil = require(Shared.Util.TimeUtil)

local ProfileOps = {}

ProfileOps.Messages = {
	insufficient_coins = "Moedas insuficientes.",
	base_full = "Sua base está cheia. Venda uma criatura ou compre mais pedestais.",
	invalid_creature = "Criatura não encontrada.",
	invalid_egg = "Ovo inválido.",
	egg_locked = "Esse ovo libera depois do primeiro renascimento.",
	invalid_upgrade = "Melhoria inválida.",
	max_level = "Já está no nível máximo.",
	valuable_locked = "Criatura valiosa: confirme a venda.",
	being_stolen = "Essa criatura está sendo carregada agora.",
	nothing_to_collect = "Nada para coletar ainda.",
	invalid_potion = "Poção inválida.",
	no_potion = "Você não tem essa poção.",
	potion_max = "Tempo máximo acumulado dessa poção.",
	already_claimed = "Já resgatado.",
	not_ready = "Ainda não concluído.",
	invalid_mission = "Missão inválida.",
	confirmation_required = "Digite a frase de confirmação.",
	rebirth_locked = "Moedas insuficientes para renascer.",
	rebirth_max = "Número máximo de renascimentos.",
	protected = "Essa criatura foi roubada há pouco e está protegida.",
	offer_gone = "Outra pessoa comprou essa criatura primeiro.",
	invalid_request = "Pedido inválido.",
}

local function fail(code)
	return false, code
end

local function addCoins(profile, n)
	profile.coins = math.max(0, math.min(GameConfig.MaxCoins, math.floor(profile.coins + n)))
end

---------------------------------------------------------------------------
-- missões (seleção diária determinística: todos recebem as mesmas no mesmo dia)
---------------------------------------------------------------------------

local function pickMissions(dayIndex)
	local pool = ProgressConfig.Missions
	local idx = {}
	for i = 1, #pool do
		idx[i] = i
	end
	local state = (math.floor(dayIndex) % 2147483646) + 1
	for i = #idx, 2, -1 do
		state = (state * 16807) % 2147483647
		local j = (state % i) + 1
		idx[i], idx[j] = idx[j], idx[i]
	end
	local out = {}
	for i = 1, math.min(ProgressConfig.DailyMissionCount, #idx) do
		table.insert(out, pool[idx[i]].id)
	end
	return out
end
ProfileOps.pickMissions = pickMissions

function ProfileOps.refreshPeriods(profile, now)
	local day = TimeUtil.dayIndex(now)
	local m = profile.missions
	if m.day ~= day then
		profile.missions = { day = day, list = pickMissions(day), progress = {}, claimed = {} }
	end
end

function ProfileOps.emit(profile, now, eventName, amount)
	ProfileOps.refreshPeriods(profile, now)
	local m = profile.missions
	for _, id in ipairs(m.list) do
		local def = ProgressConfig.MissionById[id]
		if def and def.event == eventName and not m.claimed[id] then
			m.progress[id] = math.min(def.target, (m.progress[id] or 0) + (amount or 1))
		end
	end
end

---------------------------------------------------------------------------
-- sorte
---------------------------------------------------------------------------

-- retorna (sorteTotal, fontes)
function ProfileOps.luck(profile, now)
	local list = {}
	local rb = math.min((profile.rebirths or 0) * GameConfig.Rebirth.LuckPer, GameConfig.Rebirth.LuckMax)
	if rb > 0 then
		table.insert(list, { name = "Renascimentos", luck = rb })
	end
	if (profile.activePotions.sorte or 0) > now then
		table.insert(list, { name = GameConfig.Potions.sorte.name, luck = GameConfig.Potions.sorte.luck, endsAt = profile.activePotions.sorte })
	end
	local ev = EventConfig.at(now)
	if ev and ev.kind == "luck" then
		table.insert(list, { name = ev.name, luck = ev.luck, endsAt = ev.endsAt })
	end
	local total = 0
	for _, e in ipairs(list) do
		total = total + e.luck
	end
	return math.min(total, GameConfig.Luck.Max), list
end

---------------------------------------------------------------------------
-- criaturas
---------------------------------------------------------------------------

local function indexKey(s, m)
	return s .. ":" .. m
end
ProfileOps.indexKey = indexKey

function ProfileOps.indexCount(profile)
	local n = 0
	for _ in pairs(profile.index) do
		n = n + 1
	end
	return n
end

-- adiciona uma criatura (a vaga já foi validada por quem chamou)
local function addCreature(profile, now, speciesId, mutationId, origin)
	local pad = ProfileSchema.freePad(profile)
	local uid = "c" .. tostring(profile.nextUid)
	profile.nextUid = profile.nextUid + 1
	local c = { uid = uid, s = speciesId, m = mutationId, pad = pad, since = now, at = now, origin = origin }
	profile.creatures[uid] = c
	local key = indexKey(speciesId, mutationId)
	local isNew = profile.index[key] == nil
	if isNew then
		profile.index[key] = now
		ProfileOps.emit(profile, now, "discover", 1)
	end
	if mutationId ~= "normal" then
		ProfileOps.emit(profile, now, "mutant", 1)
	end
	return c, isNew
end

function ProfileOps.canReceive(profile)
	return ProfileSchema.freePad(profile) ~= nil
end

-- compra uma criatura da esteira. offer = { speciesId, mutationId, price } (definido pelo SERVIDOR)
function ProfileOps.buyFromConveyor(profile, ctx, offer)
	if type(offer) ~= "table" or not GameConfig.SpeciesById[offer.speciesId] or not GameConfig.Mutations[offer.mutationId] then
		return fail("invalid_request")
	end
	if not ProfileOps.canReceive(profile) then
		return fail("base_full")
	end
	if profile.coins < offer.price then
		return fail("insufficient_coins")
	end
	addCoins(profile, -offer.price)
	local c, isNew = addCreature(profile, ctx.now, offer.speciesId, offer.mutationId, "conveyor")
	profile.stats.conveyorBought = profile.stats.conveyorBought + 1
	ProfileOps.emit(profile, ctx.now, "conveyorBuy", 1)
	return true, { creature = c, isNew = isNew, cost = offer.price }
end

-- sorteia uma criatura da esteira (sorte do evento; a esteira é de todos)
function ProfileOps.rollConveyor(now, r1, r2)
	local ev = EventConfig.at(now)
	local luck = 0
	if ev and (ev.kind == "luck" or ev.kind == "conveyor") then
		luck = ev.luck or 0
	end
	local sp = Odds.pick(Odds.speciesTable(GameConfig.Conveyor.RarityWeights, luck), r1)
	local mu = Odds.pick(Odds.mutationTable(luck, ev), r2)
	local s = GameConfig.SpeciesById[sp.speciesId]
	local mult = GameConfig.Mutations[mu.mutationId].mult
	return { speciesId = sp.speciesId, mutationId = mu.mutationId, price = s.price * mult }
end

-- tabelas de chance de um ovo para este jogador agora (usadas também pela interface)
function ProfileOps.eggOdds(profile, eggId, now)
	local egg = GameConfig.Eggs[eggId]
	local luck = ProfileOps.luck(profile, now)
	local ev = EventConfig.at(now)
	return Odds.speciesTable(egg.rarityWeights, luck), Odds.mutationTable(luck, ev), luck
end

function ProfileOps.hatchEgg(profile, ctx, eggId)
	local egg = GameConfig.Eggs[eggId]
	if not egg then
		return fail("invalid_egg")
	end
	if (profile.rebirths or 0) < egg.requiredRebirths then
		return fail("egg_locked")
	end
	if not ProfileOps.canReceive(profile) then
		return fail("base_full")
	end
	if profile.coins < egg.price then
		return fail("insufficient_coins")
	end
	local species, mutations, luck = ProfileOps.eggOdds(profile, eggId, ctx.now)
	local sp = Odds.pick(species, ctx.rng())
	local mu = Odds.pick(mutations, ctx.rng())
	addCoins(profile, -egg.price)
	local c, isNew = addCreature(profile, ctx.now, sp.speciesId, mu.mutationId, "egg")
	profile.stats.hatched = profile.stats.hatched + 1
	ProfileOps.emit(profile, ctx.now, "hatch", 1)
	return true, { creature = c, isNew = isNew, cost = egg.price, luck = luck }
end

-- vender: coleta o que estava guardado no pedestal e paga 50% do valor
function ProfileOps.sell(profile, ctx, uid, confirmValuable)
	local c = profile.creatures[uid]
	if not c then
		return fail("invalid_creature")
	end
	if ctx.locked and ctx.locked[uid] then
		return fail("being_stolen")
	end
	local s = GameConfig.SpeciesById[c.s]
	if GameConfig.tier(s.rarity) >= GameConfig.ValuableConfirmTier and confirmValuable ~= true then
		return fail("valuable_locked")
	end
	local pending = math.floor(Income.pending(profile, c, ctx.now))
	local price = Income.sellPrice(c)
	profile.creatures[uid] = nil
	addCoins(profile, price + pending)
	profile.stats.sold = profile.stats.sold + 1
	profile.stats.coinsCollected = profile.stats.coinsCollected + pending
	ProfileOps.emit(profile, ctx.now, "sell", 1)
	return true, { coins = price, collected = pending }
end

-- coleta o que todas as criaturas guardaram
function ProfileOps.collectAll(profile, ctx)
	local total = 0
	for _, c in pairs(profile.creatures) do
		total = total + Income.pending(profile, c, ctx.now)
	end
	local amount = math.floor(total)
	if amount <= 0 then
		return fail("nothing_to_collect")
	end
	for _, c in pairs(profile.creatures) do
		c.since = ctx.now
		c.banked = 0
	end
	addCoins(profile, amount)
	profile.stats.coinsCollected = profile.stats.coinsCollected + amount
	ProfileOps.emit(profile, ctx.now, "collect", amount)
	return true, { coins = amount }
end

-- move uma criatura para outro pedestal livre (organização da base)
function ProfileOps.movePad(profile, ctx, uid, pad)
	local c = profile.creatures[uid]
	if not c then
		return fail("invalid_creature")
	end
	if type(pad) ~= "number" or pad < 1 or pad > ProfileSchema.slots(profile) or pad ~= math.floor(pad) then
		return fail("invalid_request")
	end
	for _, other in pairs(profile.creatures) do
		if other.pad == pad and other ~= c then
			other.pad = c.pad -- troca de lugar
		end
	end
	c.pad = pad
	return true, {}
end

---------------------------------------------------------------------------
-- melhorias e poções
---------------------------------------------------------------------------

function ProfileOps.buyUpgrade(profile, ctx, id)
	local u = GameConfig.Upgrades[id]
	if not u then
		return fail("invalid_upgrade")
	end
	local level = profile.upgrades[id] or 0
	if level >= u.maxLevel then
		return fail("max_level")
	end
	local cost = GameConfig.upgradeCost(id, level)
	if profile.coins < cost then
		return fail("insufficient_coins")
	end
	if id == "storage" then
		-- guarda a produção com o cofre antigo antes de aumentar
		for _, c in pairs(profile.creatures) do
			Income.bank(profile, c, ctx.now)
		end
	end
	addCoins(profile, -cost)
	profile.upgrades[id] = level + 1
	ProfileOps.emit(profile, ctx.now, "upgrade", 1)
	return true, { id = id, level = level + 1, cost = cost }
end

function ProfileOps.shieldSeconds(profile)
	return GameConfig.Base.ShieldSeconds + (profile.upgrades.shield or 0) * GameConfig.Upgrades.shield.perLevel
end

function ProfileOps.walkSpeed(profile, now, carrying)
	local speed = GameConfig.Base.WalkSpeed + (profile.upgrades.speed or 0) * GameConfig.Upgrades.speed.perLevel
	if (profile.activePotions.velocidade or 0) > now then
		speed = speed + GameConfig.Potions.velocidade.speed
	end
	if carrying then
		speed = speed - GameConfig.Steal.CarrySpeedPenalty
	end
	return speed
end

function ProfileOps.buyPotion(profile, ctx, id)
	local p = GameConfig.Potions[id]
	if not p then
		return fail("invalid_potion")
	end
	if profile.coins < p.coinPrice then
		return fail("insufficient_coins")
	end
	addCoins(profile, -p.coinPrice)
	profile.potions[id] = (profile.potions[id] or 0) + 1
	return true, { id = id }
end

function ProfileOps.activatePotion(profile, ctx, id)
	local p = GameConfig.Potions[id]
	if not p then
		return fail("invalid_potion")
	end
	if (profile.potions[id] or 0) <= 0 then
		return fail("no_potion")
	end
	local current = math.max(ctx.now, profile.activePotions[id] or 0)
	if current - ctx.now >= p.maxStack then
		return fail("potion_max")
	end
	if id == "renda" then
		-- a poção vale a partir de agora: a produção anterior fica guardada como está
		for _, c in pairs(profile.creatures) do
			Income.bank(profile, c, ctx.now)
		end
	end
	if (profile.activePotions[id] or 0) <= ctx.now or not profile.potionStarts[id] then
		profile.potionStarts[id] = ctx.now
	end
	profile.potions[id] = profile.potions[id] - 1
	profile.activePotions[id] = math.min(current + p.duration, ctx.now + p.maxStack)
	return true, { id = id, endsAt = profile.activePotions[id] }
end

---------------------------------------------------------------------------
-- recompensas
---------------------------------------------------------------------------

function ProfileOps.rewardCoins(profile, reward)
	local coins = reward.coins or 0
	if reward.incomeMinutes then
		coins = math.max(coins, math.floor(Income.totalRate(profile) * 60 * reward.incomeMinutes))
	end
	return coins
end

function ProfileOps.grantReward(profile, reward)
	local summary = { coins = 0, potions = {} }
	local coins = ProfileOps.rewardCoins(profile, reward)
	if coins > 0 then
		addCoins(profile, coins)
		summary.coins = coins
	end
	for id, n in pairs(reward.potions or {}) do
		if GameConfig.Potions[id] then
			profile.potions[id] = (profile.potions[id] or 0) + n
			summary.potions[id] = n
		end
	end
	return summary
end

function ProfileOps.claimMission(profile, ctx, id)
	ProfileOps.refreshPeriods(profile, ctx.now)
	local m = profile.missions
	local def = ProgressConfig.MissionById[id]
	if not def or not table.find(m.list, id) then
		return fail("invalid_mission")
	end
	if m.claimed[id] then
		return fail("already_claimed")
	end
	if (m.progress[id] or 0) < def.target then
		return fail("not_ready")
	end
	m.claimed[id] = true
	return true, { reward = ProfileOps.grantReward(profile, def.reward) }
end

function ProfileOps.giftStatus(profile, now)
	local day = TimeUtil.dayIndex(now)
	local g = profile.gifts
	local nextStreak = 1
	if g.lastDay == day - 1 then
		nextStreak = (g.streak % #ProgressConfig.DailyGifts) + 1
	elseif g.lastDay == day then
		nextStreak = g.streak
	end
	return { available = g.lastDay ~= day, streak = g.streak, nextStreak = nextStreak, resetsIn = TimeUtil.secondsUntilNextDay(now) }
end

function ProfileOps.claimGift(profile, ctx)
	local st = ProfileOps.giftStatus(profile, ctx.now)
	if not st.available then
		return fail("already_claimed")
	end
	profile.gifts.lastDay = TimeUtil.dayIndex(ctx.now)
	profile.gifts.streak = st.nextStreak
	return true, { day = st.nextStreak, reward = ProfileOps.grantReward(profile, ProgressConfig.DailyGifts[st.nextStreak]) }
end

function ProfileOps.claimMilestone(profile, ctx, id)
	local def = ProgressConfig.MilestoneById[id]
	if not def then
		return fail("invalid_request")
	end
	if profile.milestones[id] then
		return fail("already_claimed")
	end
	if ProfileOps.indexCount(profile) < def.count then
		return fail("not_ready")
	end
	profile.milestones[id] = true
	return true, { reward = ProfileOps.grantReward(profile, def.reward) }
end

---------------------------------------------------------------------------
-- roubo (transferência atômica entre dois perfis no MESMO servidor)
---------------------------------------------------------------------------

-- pode pegar? (validação antes de começar a carregar)
function ProfileOps.canSteal(victim, thief, uid, now)
	local c = victim.creatures[uid]
	if not c then
		return false, "invalid_creature"
	end
	if (c.protectedUntil or 0) > now then
		return false, "protected"
	end
	if not ProfileOps.canReceive(thief) then
		return false, "base_full"
	end
	return true
end

-- entrega: remove da vítima (pagando a ela o que estava guardado) e entrega ao ladrão.
-- Valida tudo antes de alterar os dois perfis.
function ProfileOps.completeSteal(victim, thief, uid, now)
	local ok, code = ProfileOps.canSteal(victim, thief, uid, now)
	if not ok then
		return false, code
	end
	local c = victim.creatures[uid]
	local pending = math.floor(Income.pending(victim, c, now))
	victim.creatures[uid] = nil
	addCoins(victim, pending)
	victim.stats.lostToThieves = victim.stats.lostToThieves + 1
	local nc, isNew = addCreature(thief, now, c.s, c.m, "stolen")
	nc.protectedUntil = now + GameConfig.Steal.ProtectAfterSteal
	thief.stats.stolen = thief.stats.stolen + 1
	ProfileOps.emit(thief, now, "steal", 1)
	return true, { creature = nc, isNew = isNew, victimCollected = pending }
end

function ProfileOps.recordDefense(profile, now)
	profile.stats.defended = profile.stats.defended + 1
	ProfileOps.emit(profile, now, "defend", 1)
end

function ProfileOps.recordShield(profile, now)
	ProfileOps.emit(profile, now, "shield", 1)
end

---------------------------------------------------------------------------
-- renascimento: troca moedas e criaturas por bônus permanentes
---------------------------------------------------------------------------

function ProfileOps.rebirthInfo(profile)
	local n = (profile.rebirths or 0) + 1
	local R = GameConfig.Rebirth
	return {
		next = n,
		cost = GameConfig.rebirthCost(n),
		maxed = (profile.rebirths or 0) >= R.MaxRebirths,
		incomeAfter = 1 + n * R.IncomeBonusPer,
		luckAfter = math.min(n * R.LuckPer, R.LuckMax),
		creaturesLost = ProfileSchema.creatureCount(profile),
	}
end

function ProfileOps.rebirth(profile, ctx, phrase)
	if phrase ~= GameConfig.Rebirth.ConfirmPhrase then
		return fail("confirmation_required")
	end
	local info = ProfileOps.rebirthInfo(profile)
	if info.maxed then
		return fail("rebirth_max")
	end
	if profile.coins < info.cost then
		return fail("rebirth_locked")
	end
	for uid in pairs(profile.creatures) do
		if ctx.locked and ctx.locked[uid] then
			return fail("being_stolen")
		end
	end
	profile.creatures = {}
	profile.coins = GameConfig.StartingCoins
	profile.rebirths = info.next
	return true, { rebirths = info.next }
end

function ProfileOps.setSetting(profile, key, value)
	if key ~= "reduceEffects" or type(value) ~= "boolean" then
		return fail("invalid_request")
	end
	profile.settings[key] = value
	return true, {}
end

return ProfileOps
