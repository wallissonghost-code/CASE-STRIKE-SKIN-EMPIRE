-- ProfileOps: TODAS as operações que alteram o perfil do jogador.
-- Regras:
--   * Cada função valida tudo ANTES de alterar qualquer dado; depois de começar a alterar,
--     não existem pontos de falha. Como nada aqui faz yield, cada operação é atômica no servidor.
--   * Apenas o servidor chama estas funções. Valores enviados pelo cliente nunca são usados
--     como valores econômicos (só ids, quantidades permitidas e flags de confirmação).
--   * ctx = { now = número (horário do servidor, UTC), rng = função -> [0, 1) }

local Shared = script.Parent.Parent
local EconomyConfig = require(Shared.Config.EconomyConfig)
local BankConfig = require(Shared.Config.BankConfig)
local CaseDefinitions = require(Shared.Config.CaseDefinitions)
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local RarityConfig = require(Shared.Config.RarityConfig)
local UpgradeRecipes = require(Shared.Config.UpgradeRecipes)
local MissionDefinitions = require(Shared.Config.MissionDefinitions)
local ProgressionConfig = require(Shared.Config.ProgressionConfig)
local LuckConfig = require(Shared.Config.LuckConfig)
local EventDefinitions = require(Shared.Config.EventDefinitions)
local AttributeConfig = require(Shared.Config.AttributeConfig)
local AchievementDefinitions = require(Shared.Config.AchievementDefinitions)
local Probability = require(Shared.Logic.Probability)
local BankMath = require(Shared.Logic.BankMath)
local Wealth = require(Shared.Logic.Wealth)
local Progression = require(Shared.Logic.Progression)
local ProfileSchema = require(Shared.Logic.ProfileSchema)
local TimeUtil = require(Shared.Util.TimeUtil)

local ProfileOps = {}

ProfileOps.Messages = {
	invalid_case = "Caixa inválida.",
	case_unavailable = "Esta caixa não está disponível no momento.",
	invalid_quantity = "Quantidade de abertura inválida.",
	level_locked = "Nível insuficiente.",
	inventory_full = "Inventário cheio. Venda ou deposite skins.",
	insufficient_credits = "Créditos insuficientes.",
	insufficient_materials = "Materiais insuficientes.",
	invalid_item = "Item inválido ou não pertence a você.",
	item_in_bank = "A skin está depositada no banco. Retire-a primeiro.",
	item_not_in_bank = "A skin não está no banco.",
	favorite_locked = "Item favorito: confirme explicitamente para continuar.",
	bank_full = "Todas as vagas do banco estão ocupadas.",
	nothing_to_claim = "Nada para resgatar.",
	invalid_upgrade = "Melhoria inválida.",
	max_level = "Nível máximo atingido.",
	already_equipped = "A skin já está equipada.",
	not_equipped = "A skin não está equipada.",
	equip_full = "Todas as vagas de exibição estão ocupadas.",
	rarity_too_low = "Raridade insuficiente para esta receita.",
	already_upgraded = "Esta melhoria já foi aplicada.",
	already_claimed = "Recompensa já resgatada.",
	invalid_reward = "Recompensa inválida.",
	mission_inactive = "Missão não está ativa.",
	mission_incomplete = "Missão ainda não concluída.",
	collection_incomplete = "Coleção incompleta.",
	achievement_locked = "Conquista ainda não desbloqueada.",
	no_event = "Nenhum evento ativo.",
	rebirth_locked = "Requisitos de renascimento não atingidos.",
	rebirth_max = "Número máximo de renascimentos atingido.",
	confirmation_required = "Confirmação inequívoca necessária.",
	invalid_title = "Título não desbloqueado.",
	invalid_request = "Pedido inválido.",
	valuable_locked = "Skin Lendária ou Secreta: confirme explicitamente a venda.",
	quantity_locked = "Abrir 25 de uma vez exige o atributo Limite de abertura múltipla.",
	invalid_attribute = "Atributo inválido.",
	showcase_full = "Todas as vagas do showroom estão ocupadas.",
	cosmetic_locked = "Complete a coleção para desbloquear este cosmético.",
}

---------------------------------------------------------------------------
-- utilitários internos
---------------------------------------------------------------------------

local function fail(code)
	return false, code
end

local function addCredits(profile, amount)
	profile.credits = math.min(EconomyConfig.MaxCredits, math.floor(profile.credits + amount))
end

local function addMaterials(profile, mats, sign)
	sign = sign or 1
	for k, v in pairs(mats or {}) do
		profile.materials[k] = (profile.materials[k] or 0) + v * sign
	end
end

local function hasMaterials(profile, mats)
	for k, v in pairs(mats or {}) do
		if (profile.materials[k] or 0) < v then
			return false
		end
	end
	return true
end

local function logTx(profile, now, kind, data)
	profile.txSeq = (profile.txSeq or 0) + 1
	local entry = { seq = profile.txSeq, t = now, kind = kind }
	for k, v in pairs(data or {}) do
		entry[k] = v
	end
	table.insert(profile.txLog, entry)
	while #profile.txLog > EconomyConfig.TransactionLogSize do
		table.remove(profile.txLog, 1)
	end
end

local function countBank(profile)
	local n = 0
	for _, item in pairs(profile.inventory) do
		if item.location == "bank" then
			n = n + 1
		end
	end
	return n
end

local function countEquipped(profile)
	local n = 0
	for _, item in pairs(profile.inventory) do
		if item.equipped then
			n = n + 1
		end
	end
	return n
end

-- XP central: aplica multiplicador/limites, emite "levelUp" e libera títulos de nível
local function unlockLevelTitles(profile)
	for _, id in ipairs(ProgressionConfig.LevelTitleOrder) do
		local t = ProgressionConfig.Titles[id]
		if profile.level >= t.level then
			profile.titles[id] = true
		end
	end
end

local function giveXp(profile, amount, source, now)
	local got, levels = Progression.addXp(profile, amount, source, now)
	if levels > 0 then
		unlockLevelTitles(profile)
		ProfileOps.emit(profile, now, "levelUp", {}, levels)
	end
	return got, levels
end
ProfileOps._giveXp = giveXp

local function newItem(profile, defId, now, caseId)
	local uid = "i" .. tostring(profile.nextUid)
	profile.nextUid = profile.nextUid + 1
	local item = {
		uid = uid,
		defId = defId,
		obtainedAt = now,
		caseId = caseId,
		favorite = false,
		equipped = false,
		location = "inventory",
		upgrades = {},
	}
	profile.inventory[uid] = item
	return item
end

---------------------------------------------------------------------------
-- períodos (missões diárias/semanais e eventos)
---------------------------------------------------------------------------

function ProfileOps.featuredCollection(now)
	local ev = EventDefinitions.activeEvent(now)
	if ev then
		return ev.featuredCollection
	end
	local rot = EventDefinitions.WeeklyFeaturedRotation
	return rot[(TimeUtil.weekIndex(now) % #rot) + 1]
end

function ProfileOps.refreshPeriods(profile, now)
	local m = profile.missions
	local day = TimeUtil.dayIndex(now)
	local week = TimeUtil.weekIndex(now)
	if m.day ~= day then
		for _, id in ipairs(m.daily) do
			m.progress[id] = nil
			m.claimed[id] = nil
		end
		m.daily = MissionDefinitions.dailyFor(day)
		m.day = day
		for _, id in ipairs(m.daily) do
			m.progress[id] = 0
			m.claimed[id] = nil
		end
	end
	if m.week ~= week then
		for _, id in ipairs(m.weekly) do
			m.progress[id] = nil
			m.claimed[id] = nil
		end
		m.weekly = MissionDefinitions.weeklyFor(week)
		m.week = week
		for _, id in ipairs(m.weekly) do
			m.progress[id] = 0
			m.claimed[id] = nil
		end
	end
	local ev = EventDefinitions.activeEvent(now)
	local evId = ev and ev.id or ""
	if profile.eventProgress.eventId ~= evId then
		profile.eventProgress = { eventId = evId, progress = {}, claimed = {} }
	end
end

local function matchesFilter(filter, payload)
	if not filter then
		return true
	end
	if filter.rarity and payload.rarity ~= filter.rarity then
		return false
	end
	if filter.minTier and (payload.tier or 0) < filter.minTier then
		return false
	end
	if filter.collection and payload.collection ~= filter.collection then
		return false
	end
	if filter.collections then
		local ok = false
		for _, c in ipairs(filter.collections) do
			if c == payload.collection then
				ok = true
			end
		end
		if not ok then
			return false
		end
	end
	if filter.caseId and payload.caseId ~= filter.caseId then
		return false
	end
	return true
end

-- Emite um evento de progresso para missões e desafios de evento.
function ProfileOps.emit(profile, now, eventName, payload, amount)
	amount = amount or 1
	payload = payload or {}
	local m = profile.missions
	local function bump(list)
		for _, id in ipairs(list) do
			local def = MissionDefinitions.ById[id]
			if def and def.event == eventName and not m.claimed[id] and matchesFilter(def.filter, payload) then
				m.progress[id] = math.min(def.target, (m.progress[id] or 0) + amount)
			end
		end
	end
	bump(m.daily)
	bump(m.weekly)

	local ev = EventDefinitions.activeEvent(now)
	if ev and profile.eventProgress.eventId == ev.id then
		local ep = profile.eventProgress
		for _, c in ipairs(ev.challenges) do
			if c.event == eventName and not ep.claimed[c.id] and matchesFilter(c.filter, payload) then
				ep.progress[c.id] = math.min(c.target, (ep.progress[c.id] or 0) + amount)
			end
		end
	end
end

---------------------------------------------------------------------------
-- sorte
---------------------------------------------------------------------------

-- Retorna (sorteTotal, listaDeFontes). Remove modificadores expirados.
function ProfileOps.activeLuck(profile, now)
	local list = {}
	local kept = {}
	for _, mod in ipairs(profile.luck.modifiers) do
		local def = LuckConfig.Modifiers[mod.id]
		local alive = def ~= nil
		if alive and def.kind == "timed" and (mod.expiresAt or 0) <= now then
			alive = false
		end
		if alive and def.kind == "uses" and (mod.usesLeft or 0) <= 0 then
			alive = false
		end
		if alive then
			table.insert(kept, mod)
			table.insert(list, {
				id = def.id,
				displayName = def.displayName,
				source = def.source,
				kind = def.kind,
				luck = def.luck,
				expiresAt = mod.expiresAt,
				usesLeft = mod.usesLeft,
			})
		end
	end
	profile.luck.modifiers = kept

	local rb = math.min((profile.rebirths or 0) * ProgressionConfig.Rebirth.LuckPerRebirth, ProgressionConfig.Rebirth.LuckMax)
	if rb > 0 then
		table.insert(list, {
			id = "luck_rebirth",
			displayName = "Legado do renascimento",
			source = "Renascimentos (" .. tostring(profile.rebirths) .. ")",
			kind = "permanent",
			luck = rb,
		})
	end

	local attrLuck = (profile.attributes and profile.attributes.luck or 0) * AttributeConfig.Attributes.luck.perLevel
	if attrLuck > 0 then
		table.insert(list, {
			id = "luck_attribute",
			displayName = "Atributo Sorte",
			source = "Atributos (nível " .. tostring(profile.attributes.luck) .. ")",
			kind = "permanent",
			luck = attrLuck,
		})
	end

	local ev = EventDefinitions.activeEvent(now)
	if ev and ev.luckModifier then
		local def = LuckConfig.Modifiers[ev.luckModifier]
		if def then
			table.insert(list, {
				id = def.id,
				displayName = def.displayName .. ": " .. ev.name,
				source = def.source,
				kind = "event",
				luck = def.luck,
				expiresAt = ev.endsAt,
			})
		end
	end

	local total = 0
	for _, e in ipairs(list) do
		total = total + e.luck
	end
	return math.min(total, LuckConfig.MaxTotalLuck), list
end

function ProfileOps.grantLuck(profile, modId, now)
	local def = LuckConfig.Modifiers[modId]
	if not def or def.kind == "event" then
		return false
	end
	for _, mod in ipairs(profile.luck.modifiers) do
		if mod.id == modId then
			-- maxStacks = 1: renova em vez de acumular
			if def.kind == "timed" then
				mod.expiresAt = now + def.duration
			else
				mod.usesLeft = def.uses
			end
			return true
		end
	end
	local mod = { id = modId }
	if def.kind == "timed" then
		mod.expiresAt = now + def.duration
	else
		mod.usesLeft = def.uses
	end
	table.insert(profile.luck.modifiers, mod)
	return true
end

local function consumeLuckUses(profile, n)
	for _, mod in ipairs(profile.luck.modifiers) do
		local def = LuckConfig.Modifiers[mod.id]
		if def and def.kind == "uses" and (mod.usesLeft or 0) > 0 then
			mod.usesLeft = math.max(0, mod.usesLeft - n)
		end
	end
end

-- Tabela de probabilidades finais (com sorte) que o servidor usará nesta abertura.
function ProfileOps.caseOdds(profile, caseId, now)
	local caseDef = CaseDefinitions.ById[caseId]
	if not caseDef then
		return nil
	end
	local luck = ProfileOps.activeLuck(profile, now)
	return Probability.computeTable(caseDef, luck), luck
end

---------------------------------------------------------------------------
-- conquistas e coleções
---------------------------------------------------------------------------

function ProfileOps.collectionStatus(profile)
	local out = {}
	for _, caseDef in ipairs(CaseDefinitions.List) do
		local skins = SkinDefinitions.ByCase[caseDef.id]
		local found = 0
		for _, s in ipairs(skins) do
			if profile.discovered[s.id] then
				found = found + 1
			end
		end
		out[caseDef.id] = {
			id = caseDef.id,
			total = #skins,
			discovered = found,
			complete = found >= #skins,
			claimed = profile.collectionsClaimed[caseDef.id] == true,
		}
	end
	return out
end

function ProfileOps.statValue(profile, stat)
	if stat == "uniqueDiscovered" then
		local n = 0
		for _ in pairs(profile.discovered) do
			n = n + 1
		end
		return n
	elseif stat == "collectionsCompleted" then
		local n = 0
		for _, st in pairs(ProfileOps.collectionStatus(profile)) do
			if st.complete then
				n = n + 1
			end
		end
		return n
	elseif stat == "netWorth" then
		return Wealth.netWorth(profile)
	elseif stat == "level" then
		return profile.level
	elseif stat == "rebirths" then
		return profile.rebirths
	elseif stat == "bankIncome" then
		return BankMath.totalRate(profile)
	end
	return profile.stats[stat] or 0
end

function ProfileOps.checkAchievements(profile, now)
	local unlocked = {}
	local changed = true
	while changed do
		changed = false
		for _, a in ipairs(AchievementDefinitions.List) do
			if not profile.achievements[a.id] and ProfileOps.statValue(profile, a.stat) >= a.target then
				profile.achievements[a.id] = now
				table.insert(unlocked, a.id)
				giveXp(profile, ProgressionConfig.AchievementXp, nil, now) -- pode liberar conquistas de nível
				changed = true
			end
		end
	end
	return unlocked
end

---------------------------------------------------------------------------
-- recompensas
---------------------------------------------------------------------------

-- Concede uma recompensa. xpSource = fonte para limites diários (nil = sem limite).
function ProfileOps.grantReward(profile, now, reward, xpSource)
	local summary = { credits = 0, xp = 0, levelsGained = 0, materials = {}, freeCases = {} }
	if reward.credits then
		addCredits(profile, reward.credits)
		summary.credits = reward.credits
	end
	if reward.xp then
		local got, lv = giveXp(profile, reward.xp, xpSource, now)
		summary.xp = got
		summary.levelsGained = lv
	end
	if reward.materials then
		addMaterials(profile, reward.materials)
		summary.materials = reward.materials
	end
	if reward.freeCases then
		for caseId, n in pairs(reward.freeCases) do
			if CaseDefinitions.ById[caseId] then
				profile.freeCases[caseId] = (profile.freeCases[caseId] or 0) + n
				summary.freeCases[caseId] = n
			end
		end
	end
	if reward.luck then
		ProfileOps.grantLuck(profile, reward.luck, now)
		summary.luck = reward.luck
	end
	if reward.title and ProgressionConfig.Titles[reward.title] then
		profile.titles[reward.title] = true
		summary.title = reward.title
	end
	return summary
end

---------------------------------------------------------------------------
-- abertura de caixas
---------------------------------------------------------------------------

-- opts = { useFree = bool }
function ProfileOps.openCases(profile, ctx, caseId, quantity, opts)
	opts = opts or {}
	local now = ctx.now
	local caseDef = CaseDefinitions.ById[caseId]
	if not caseDef then
		return fail("invalid_case")
	end
	if not caseDef.available then
		return fail("case_unavailable")
	end
	if type(quantity) ~= "number" or not CaseDefinitions.AllowedQuantities[quantity] then
		return fail("invalid_quantity")
	end
	if profile.level < caseDef.requiredLevel then
		return fail("level_locked")
	end
	if quantity > AttributeConfig.maxQuantity(profile.attributes and profile.attributes.multiOpen) then
		return fail("quantity_locked")
	end
	if caseDef.eventId then
		local ev = EventDefinitions.activeEvent(now)
		if not ev or ev.id ~= caseDef.eventId then
			return fail("case_unavailable")
		end
	end
	if ProfileSchema.itemCount(profile) + quantity > EconomyConfig.InventoryCapacity then
		return fail("inventory_full")
	end
	local freeAvailable = profile.freeCases[caseId] or 0
	local useFree = opts.useFree == true and freeAvailable >= quantity
	local cost = useFree and 0 or caseDef.price * quantity
	if profile.credits < cost then
		return fail("insufficient_credits")
	end

	ProfileOps.refreshPeriods(profile, now)
	local luck = ProfileOps.activeLuck(profile, now)
	local entries = Probability.computeTable(caseDef, luck)

	-- 1) sorteia todos os resultados antes de alterar qualquer coisa
	local draws = {}
	for i = 1, quantity do
		draws[i] = Probability.pick(entries, ctx.rng())
	end

	-- 2) aplica tudo de uma vez (sem pontos de falha a partir daqui)
	if useFree then
		local left = freeAvailable - quantity
		profile.freeCases[caseId] = left > 0 and left or nil
	else
		addCredits(profile, -cost)
		profile.stats.creditsSpentOnCases = profile.stats.creditsSpentOnCases + cost
	end
	consumeLuckUses(profile, quantity)

	local results = {}
	local levelsGained = 0
	local featured = ProfileOps.featuredCollection(now)
	for _, draw in ipairs(draws) do
		local def = SkinDefinitions.ById[draw.skinId]
		local item = newItem(profile, def.id, now, caseId)
		local isNew = profile.discovered[def.id] == nil
		local tier = RarityConfig.tier(def.rarity)
		local payload = { rarity = def.rarity, tier = tier, collection = def.collection, caseId = caseId }
		if isNew then
			profile.discovered[def.id] = now
			local _, lv = giveXp(profile, RarityConfig.Rarities[def.rarity].discoverXp, nil, now)
			levelsGained = levelsGained + lv
			ProfileOps.emit(profile, now, "discover", payload, 1)
			if def.collection == featured then
				ProfileOps.emit(profile, now, "discoverFeatured", payload, 1)
			end
			if ProfileOps.collectionStatus(profile)[def.collection].complete then
				ProfileOps.emit(profile, now, "collectionComplete", payload, 1)
			end
		end
		ProfileOps.emit(profile, now, "obtain", payload, 1)
		if def.value > profile.stats.bestDropValue then
			profile.stats.bestDropValue = def.value
		end
		table.insert(results, { uid = item.uid, defId = def.id, isNew = isNew })
	end

	profile.stats.casesOpened = profile.stats.casesOpened + quantity
	local _, lv = giveXp(profile, EconomyConfig.Opening.XpPerOpen * quantity, "open", now)
	levelsGained = levelsGained + lv
	ProfileOps.emit(profile, now, "open", { caseId = caseId }, quantity)
	local newAchievements = ProfileOps.checkAchievements(profile, now)

	local defIds = {}
	for i, r in ipairs(results) do
		defIds[i] = r.defId
	end
	logTx(profile, now, "open", { caseId = caseId, qty = quantity, cost = cost, free = useFree, drops = defIds })

	return true, {
		caseId = caseId,
		quantity = quantity,
		cost = cost,
		usedFree = useFree,
		luck = luck,
		results = results,
		levelsGained = levelsGained,
		achievements = newAchievements,
	}
end

---------------------------------------------------------------------------
-- inventário
---------------------------------------------------------------------------

function ProfileOps.sellPreview(profile, uids)
	local total = 0
	for _, uid in ipairs(uids) do
		local item = profile.inventory[uid]
		if item then
			total = total + math.floor(Wealth.itemValue(item) * EconomyConfig.SellRate)
		end
	end
	return total
end

-- Venda atômica de uma ou mais instâncias. confirmFavorites precisa ser true para vender favoritas.
-- confirmValuable precisa ser true para vender Lendárias/Secretas (EconomyConfig.ValuableConfirmTier).
function ProfileOps.sellItems(profile, ctx, uids, confirmFavorites, confirmValuable)
	local now = ctx.now
	if type(uids) ~= "table" or #uids == 0 or #uids > 200 then
		return fail("invalid_request")
	end
	local seen = {}
	local total = 0
	local mats = {}
	local soldDefs = {}
	-- validação completa primeiro
	for _, uid in ipairs(uids) do
		if type(uid) ~= "string" or seen[uid] then
			return fail("invalid_request")
		end
		seen[uid] = true
		local item = profile.inventory[uid]
		if not item then
			return fail("invalid_item")
		end
		if item.location == "bank" then
			return fail("item_in_bank")
		end
		if item.favorite and confirmFavorites ~= true then
			return fail("favorite_locked")
		end
		local def = SkinDefinitions.ById[item.defId]
		if RarityConfig.tier(def.rarity) >= EconomyConfig.ValuableConfirmTier and confirmValuable ~= true then
			return fail("valuable_locked")
		end
		total = total + math.floor(def.value * EconomyConfig.SellRate)
		for k, v in pairs(EconomyConfig.SellMaterials[def.rarity] or {}) do
			mats[k] = (mats[k] or 0) + v
		end
	end
	-- aplica
	for _, uid in ipairs(uids) do
		local item = profile.inventory[uid]
		local def = SkinDefinitions.ById[item.defId]
		profile.inventory[uid] = nil
		table.insert(soldDefs, def.id)
		ProfileOps.emit(profile, now, "sell", { rarity = def.rarity, tier = RarityConfig.tier(def.rarity), collection = def.collection }, 1)
	end
	addCredits(profile, total)
	addMaterials(profile, mats)
	profile.stats.skinsSold = profile.stats.skinsSold + #uids
	profile.stats.creditsFromSales = profile.stats.creditsFromSales + total
	local newAchievements = ProfileOps.checkAchievements(profile, now)
	logTx(profile, now, "sell", { count = #uids, defs = soldDefs, credits = total })
	return true, { sold = #uids, credits = total, materials = mats, achievements = newAchievements }
end

function ProfileOps.setFavorite(profile, ctx, uid, value)
	local item = profile.inventory[uid]
	if not item then
		return fail("invalid_item")
	end
	item.favorite = value == true
	return true, { uid = uid, favorite = item.favorite }
end

function ProfileOps.equip(profile, ctx, uid)
	local item = profile.inventory[uid]
	if not item then
		return fail("invalid_item")
	end
	if item.location == "bank" then
		return fail("item_in_bank")
	end
	if item.equipped then
		return fail("already_equipped")
	end
	if countEquipped(profile) >= ProfileSchema.equipSlots(profile) then
		return fail("equip_full")
	end
	item.equipped = true
	ProfileOps.emit(profile, ctx.now, "equip", {}, 1)
	return true, { uid = uid }
end

function ProfileOps.unequip(profile, ctx, uid)
	local item = profile.inventory[uid]
	if not item then
		return fail("invalid_item")
	end
	if not item.equipped then
		return fail("not_equipped")
	end
	item.equipped = false
	return true, { uid = uid }
end

---------------------------------------------------------------------------
-- banco
---------------------------------------------------------------------------

function ProfileOps.deposit(profile, ctx, uid)
	local now = ctx.now
	local item = profile.inventory[uid]
	if not item then
		return fail("invalid_item")
	end
	if item.location == "bank" then
		return fail("item_in_bank")
	end
	if countBank(profile) >= BankMath.slots(profile) then
		return fail("bank_full")
	end
	BankMath.settle(profile, now) -- liquida com a taxa antiga antes de mudar
	item.location = "bank"
	item.equipped = false
	item.showcase = nil
	item.depositedAt = now
	ProfileOps.emit(profile, now, "deposit", {}, 1)
	logTx(profile, now, "deposit", { uid = uid })
	return true, { uid = uid }
end

function ProfileOps.withdraw(profile, ctx, uid)
	local now = ctx.now
	local item = profile.inventory[uid]
	if not item then
		return fail("invalid_item")
	end
	if item.location ~= "bank" then
		return fail("item_not_in_bank")
	end
	BankMath.settle(profile, now)
	item.location = "inventory"
	item.depositedAt = nil
	logTx(profile, now, "withdraw", { uid = uid })
	return true, { uid = uid }
end

function ProfileOps.claimBank(profile, ctx)
	local now = ctx.now
	BankMath.settle(profile, now)
	local amount = math.floor(profile.bank.pending)
	if amount <= 0 then
		return fail("nothing_to_claim")
	end
	profile.bank.pending = profile.bank.pending - amount
	addCredits(profile, amount)
	profile.stats.bankClaimedTotal = profile.stats.bankClaimedTotal + amount
	ProfileOps.emit(profile, now, "bankClaim", {}, 1)
	local newAchievements = ProfileOps.checkAchievements(profile, now)
	logTx(profile, now, "bankClaim", { credits = amount })
	return true, { credits = amount, achievements = newAchievements }
end

function ProfileOps.buyBankUpgrade(profile, ctx, upgradeId)
	local now = ctx.now
	local u = BankConfig.Upgrades[upgradeId]
	if not u then
		return fail("invalid_upgrade")
	end
	local lvl = BankMath.upgradeLevel(profile, upgradeId)
	if lvl >= u.maxLevel then
		return fail("max_level")
	end
	if profile.level < u.requiredLevel(lvl) then
		return fail("level_locked")
	end
	local cost = BankMath.upgradeCost(upgradeId, lvl)
	if profile.credits < cost then
		return fail("insufficient_credits")
	end
	BankMath.settle(profile, now)
	addCredits(profile, -cost)
	profile.bank.upgrades[upgradeId] = lvl + 1
	logTx(profile, now, "bankUpgrade", { upgrade = upgradeId, level = lvl + 1, cost = cost })
	return true, { upgrade = upgradeId, level = lvl + 1, cost = cost }
end

---------------------------------------------------------------------------
-- oficina
---------------------------------------------------------------------------

function ProfileOps.upgradeQuote(profile, uid, recipeId)
	local item = profile.inventory[uid]
	local recipe = UpgradeRecipes.ById[recipeId]
	if not item or not recipe then
		return nil
	end
	local def = SkinDefinitions.ById[item.defId]
	return {
		credits = UpgradeRecipes.creditCost(recipe, def.value),
		materials = recipe.materials,
		result = recipe.effect,
	}
end

function ProfileOps.applyUpgrade(profile, ctx, uid, recipeId)
	local now = ctx.now
	local item = profile.inventory[uid]
	if not item then
		return fail("invalid_item")
	end
	if item.location == "bank" then
		return fail("item_in_bank")
	end
	local recipe = UpgradeRecipes.ById[recipeId]
	if not recipe then
		return fail("invalid_upgrade")
	end
	local def = SkinDefinitions.ById[item.defId]
	if RarityConfig.tier(def.rarity) < recipe.minRarityTier then
		return fail("rarity_too_low")
	end
	if item.upgrades[recipeId] then
		return fail("already_upgraded")
	end
	local cost = UpgradeRecipes.creditCost(recipe, def.value)
	if profile.credits < cost then
		return fail("insufficient_credits")
	end
	if not hasMaterials(profile, recipe.materials) then
		return fail("insufficient_materials")
	end
	-- aplica: consome e entrega o resultado garantido na mesma operação
	addCredits(profile, -cost)
	addMaterials(profile, recipe.materials, -1)
	item.upgrades[recipeId] = true
	profile.stats.upgradesDone = profile.stats.upgradesDone + 1
	local _, lv = giveXp(profile, recipe.xp, "upgrade", now)
	ProfileOps.emit(profile, now, "upgrade", { rarity = def.rarity, tier = RarityConfig.tier(def.rarity) }, 1)
	local newAchievements = ProfileOps.checkAchievements(profile, now)
	logTx(profile, now, "upgrade", { uid = uid, recipe = recipeId, cost = cost })
	return true, { uid = uid, recipe = recipeId, cost = cost, levelsGained = lv, achievements = newAchievements }
end

---------------------------------------------------------------------------
-- presentes, missões, coleções, conquistas
---------------------------------------------------------------------------

function ProfileOps.dailyStatus(profile, now)
	local day = TimeUtil.dayIndex(now)
	local r = profile.rewards
	local available = r.lastDailyDay ~= day
	local nextStreak = 1
	if r.lastDailyDay == day - 1 then
		nextStreak = (r.dailyStreak % #ProgressionConfig.DailyRewards) + 1
	elseif r.lastDailyDay == day then
		nextStreak = r.dailyStreak
	end
	return {
		available = available,
		streak = r.dailyStreak,
		nextStreak = nextStreak,
		secondsUntilReset = TimeUtil.secondsUntilNextDay(now),
	}
end

function ProfileOps.claimDaily(profile, ctx)
	local now = ctx.now
	local st = ProfileOps.dailyStatus(profile, now)
	if not st.available then
		return fail("already_claimed")
	end
	local reward = ProgressionConfig.DailyRewards[st.nextStreak]
	profile.rewards.lastDailyDay = TimeUtil.dayIndex(now)
	profile.rewards.dailyStreak = st.nextStreak
	local summary = ProfileOps.grantReward(profile, now, reward, nil)
	ProfileOps.checkAchievements(profile, now)
	logTx(profile, now, "daily", { streak = st.nextStreak })
	return true, { streak = st.nextStreak, reward = summary }
end

function ProfileOps.claimLevelReward(profile, ctx, level)
	local now = ctx.now
	local reward = ProgressionConfig.LevelRewards[level]
	if type(level) ~= "number" or not reward then
		return fail("invalid_reward")
	end
	if profile.rewards.levelClaimed[tostring(level)] then
		return fail("already_claimed")
	end
	if profile.level < level then
		return fail("level_locked")
	end
	profile.rewards.levelClaimed[tostring(level)] = true
	local summary = ProfileOps.grantReward(profile, now, reward, nil)
	ProfileOps.checkAchievements(profile, now)
	logTx(profile, now, "levelReward", { level = level })
	return true, { level = level, reward = summary }
end

function ProfileOps.claimMission(profile, ctx, missionId)
	local now = ctx.now
	ProfileOps.refreshPeriods(profile, now)
	local def = MissionDefinitions.ById[missionId]
	if not def then
		return fail("invalid_reward")
	end
	local m = profile.missions
	local active = false
	for _, id in ipairs(def.period == "daily" and m.daily or m.weekly) do
		if id == missionId then
			active = true
		end
	end
	if not active then
		return fail("mission_inactive")
	end
	if m.claimed[missionId] then
		return fail("already_claimed")
	end
	if (m.progress[missionId] or 0) < def.target then
		return fail("mission_incomplete")
	end
	m.claimed[missionId] = true
	local summary = ProfileOps.grantReward(profile, now, def.reward, nil)
	ProfileOps.checkAchievements(profile, now)
	logTx(profile, now, "mission", { mission = missionId })
	return true, { mission = missionId, reward = summary }
end

function ProfileOps.claimEventChallenge(profile, ctx, challengeId)
	local now = ctx.now
	ProfileOps.refreshPeriods(profile, now)
	local ev = EventDefinitions.activeEvent(now)
	if not ev then
		return fail("no_event")
	end
	local c = EventDefinitions.ChallengeById[challengeId]
	if not c or c.eventId ~= ev.id then
		return fail("mission_inactive")
	end
	local ep = profile.eventProgress
	if ep.claimed[challengeId] then
		return fail("already_claimed")
	end
	if (ep.progress[challengeId] or 0) < c.target then
		return fail("mission_incomplete")
	end
	ep.claimed[challengeId] = true
	local summary = ProfileOps.grantReward(profile, now, c.reward, "event")
	ProfileOps.checkAchievements(profile, now)
	logTx(profile, now, "eventChallenge", { challenge = challengeId })
	return true, { challenge = challengeId, reward = summary }
end

function ProfileOps.claimCollection(profile, ctx, collectionId)
	local now = ctx.now
	local reward = ProgressionConfig.CollectionRewards[collectionId]
	if not reward then
		return fail("invalid_reward")
	end
	local st = ProfileOps.collectionStatus(profile)[collectionId]
	if st.claimed then
		return fail("already_claimed")
	end
	if not st.complete then
		return fail("collection_incomplete")
	end
	profile.collectionsClaimed[collectionId] = true
	local summary = ProfileOps.grantReward(profile, now, reward, nil)
	summary.cosmetics = {}
	for _, kind in ipairs(ProgressionConfig.CollectionCosmetics) do
		local id = kind .. "_" .. collectionId
		profile.cosmetics[id] = true
		table.insert(summary.cosmetics, id)
	end
	ProfileOps.checkAchievements(profile, now)
	logTx(profile, now, "collection", { collection = collectionId })
	return true, { collection = collectionId, reward = summary }
end

function ProfileOps.claimAchievement(profile, ctx, achievementId)
	local now = ctx.now
	local a = AchievementDefinitions.ById[achievementId]
	if not a then
		return fail("invalid_reward")
	end
	if profile.achievementsClaimed[achievementId] then
		return fail("already_claimed")
	end
	if not profile.achievements[achievementId] then
		return fail("achievement_locked")
	end
	profile.achievementsClaimed[achievementId] = true
	local summary = ProfileOps.grantReward(profile, now, a.reward, nil)
	logTx(profile, now, "achievement", { achievement = achievementId })
	return true, { achievement = achievementId, reward = summary }
end

function ProfileOps.setTitle(profile, ctx, titleId)
	if type(titleId) ~= "string" or not profile.titles[titleId] then
		return fail("invalid_title")
	end
	profile.equippedTitle = titleId
	return true, { title = titleId }
end

function ProfileOps.setFastOpen(profile, ctx, value)
	profile.settings.fastOpen = value == true
	return true, { fastOpen = profile.settings.fastOpen }
end

function ProfileOps.setReduceEffects(profile, ctx, value)
	profile.settings.reduceEffects = value == true
	return true, { reduceEffects = profile.settings.reduceEffects }
end

---------------------------------------------------------------------------
-- showroom (cosmético)
---------------------------------------------------------------------------

function ProfileOps.showcaseCount(profile)
	local n = 0
	for _, item in pairs(profile.inventory) do
		if item.showcase then
			n = n + 1
		end
	end
	return n
end

function ProfileOps.setShowcase(profile, ctx, uid, value)
	local item = profile.inventory[uid]
	if not item then
		return fail("invalid_item")
	end
	if value then
		if item.location == "bank" then
			return fail("item_in_bank")
		end
		if not item.showcase and ProfileOps.showcaseCount(profile) >= EconomyConfig.ShowcaseSlots then
			return fail("showcase_full")
		end
		item.showcase = true
	else
		item.showcase = nil
	end
	return true, { uid = uid, showcase = item.showcase == true }
end

---------------------------------------------------------------------------
-- atributos
---------------------------------------------------------------------------

-- nível atual de um atributo (os vinculados leem a melhoria do banco)
function ProfileOps.attributeLevel(profile, attrId)
	local attr = AttributeConfig.Attributes[attrId]
	if not attr then
		return 0
	end
	if attr.linkedBankUpgrade then
		return BankMath.upgradeLevel(profile, attr.linkedBankUpgrade)
	end
	return profile.attributes[attrId] or 0
end

-- dados exibidos no painel: nível, limite, custo, requisito, benefício atual e seguinte
function ProfileOps.attributeInfo(profile, attrId)
	local attr = AttributeConfig.Attributes[attrId]
	local level = ProfileOps.attributeLevel(profile, attrId)
	local maxLevel, cost, req
	if attr.linkedBankUpgrade then
		local u = BankConfig.Upgrades[attr.linkedBankUpgrade]
		maxLevel = u.maxLevel
		if level < maxLevel then
			cost = BankMath.upgradeCost(attr.linkedBankUpgrade, level)
			req = u.requiredLevel(level)
		end
	else
		maxLevel = attr.maxLevel
		if level < maxLevel then
			cost = AttributeConfig.cost(attr, level)
			req = attr.requiredLevel(level)
		end
	end
	return {
		id = attrId,
		displayName = attr.displayName,
		description = attr.description,
		level = level,
		maxLevel = maxLevel,
		cost = cost,
		requiredLevel = req,
		benefit = attr.benefit(level),
		nextBenefit = level < maxLevel and attr.benefit(level + 1) or nil,
		linked = attr.linkedBankUpgrade,
	}
end

function ProfileOps.buyAttribute(profile, ctx, attrId)
	local attr = AttributeConfig.Attributes[attrId]
	if not attr then
		return fail("invalid_attribute")
	end
	if attr.linkedBankUpgrade then
		return ProfileOps.buyBankUpgrade(profile, ctx, attr.linkedBankUpgrade)
	end
	local level = profile.attributes[attrId] or 0
	if level >= attr.maxLevel then
		return fail("max_level")
	end
	if profile.level < attr.requiredLevel(level) then
		return fail("level_locked")
	end
	local cost = AttributeConfig.cost(attr, level)
	if profile.credits < cost then
		return fail("insufficient_credits")
	end
	addCredits(profile, -cost)
	profile.attributes[attrId] = level + 1
	logTx(profile, ctx.now, "attribute", { attribute = attrId, level = level + 1, cost = cost })
	return true, { attribute = attrId, level = level + 1, cost = cost }
end

-- Variante exclusiva da coleção: grátis para skins de uma coleção concluída e resgatada.
function ProfileOps.applyCollectionVariant(profile, ctx, uid)
	local item = profile.inventory[uid]
	if not item then
		return fail("invalid_item")
	end
	if item.location == "bank" then
		return fail("item_in_bank")
	end
	local def = SkinDefinitions.ById[item.defId]
	if not profile.cosmetics["variant_" .. def.collection] then
		return fail("cosmetic_locked")
	end
	if item.upgrades.colVariant then
		return fail("already_upgraded")
	end
	item.upgrades.colVariant = true
	logTx(profile, ctx.now, "colVariant", { uid = uid })
	return true, { uid = uid }
end

---------------------------------------------------------------------------
-- renascimento
---------------------------------------------------------------------------

local function keepsOnRebirth(item)
	local def = SkinDefinitions.ById[item.defId]
	if not def then
		return false
	end
	if RarityConfig.tier(def.rarity) >= ProgressionConfig.Rebirth.KeepMinTier then
		return true
	end
	return ProgressionConfig.Rebirth.KeepFavorites and item.favorite == true
end

function ProfileOps.rebirthPreview(profile, now)
	local R = ProgressionConfig.Rebirth
	local nextN = profile.rebirths + 1
	local reqLevel = R.requiredLevel(nextN)
	local reqWorth = R.requiredNetWorth(nextN)
	local worth = Wealth.netWorth(profile)
	local keep = { count = 0, value = 0 }
	local lose = { count = 0, value = 0 }
	for _, item in pairs(profile.inventory) do
		local v = Wealth.itemValue(item)
		if keepsOnRebirth(item) then
			keep.count = keep.count + 1
			keep.value = keep.value + v
		else
			lose.count = lose.count + 1
			lose.value = lose.value + v
		end
	end
	return {
		next = nextN,
		maxed = profile.rebirths >= R.MaxRebirths,
		requiredLevel = reqLevel,
		requiredNetWorth = reqWorth,
		level = profile.level,
		netWorth = worth,
		canRebirth = profile.rebirths < R.MaxRebirths and profile.level >= reqLevel and worth >= reqWorth,
		keepItems = keep,
		loseItems = lose,
		creditsLost = profile.credits,
		pendingBankLost = math.floor(profile.bank.pending or 0),
		creditsAfter = EconomyConfig.StartingCredits,
		bankEfficiencyAfter = math.min(nextN * R.BankEfficiencyPerRebirth, R.BankEfficiencyMax),
		luckAfter = math.min(nextN * R.LuckPerRebirth, R.LuckMax),
		equipSlotBonusAfter = math.floor(nextN / R.ExtraEquipSlotEvery),
		bankSlotBonusAfter = math.floor(nextN / R.ExtraBankSlotEvery),
		xpBonusAfter = math.min(nextN * R.XpBonusPerRebirth, R.XpBonusMax),
		confirmPhrase = R.ConfirmPhrase,
	}
end

function ProfileOps.rebirth(profile, ctx, confirmPhrase)
	local now = ctx.now
	local R = ProgressionConfig.Rebirth
	if confirmPhrase ~= R.ConfirmPhrase then
		return fail("confirmation_required")
	end
	local preview = ProfileOps.rebirthPreview(profile, now)
	if preview.maxed then
		return fail("rebirth_max")
	end
	if not preview.canRebirth then
		return fail("rebirth_locked")
	end

	-- remove itens não preservados
	local removedDefs = {}
	local toRemove = {}
	for uid, item in pairs(profile.inventory) do
		if not keepsOnRebirth(item) then
			table.insert(toRemove, uid)
		end
	end
	for _, uid in ipairs(toRemove) do
		table.insert(removedDefs, profile.inventory[uid].defId)
		profile.inventory[uid] = nil
	end

	profile.credits = EconomyConfig.StartingCredits
	profile.level = 1
	profile.xp = 0
	profile.rebirths = profile.rebirths + 1
	profile.bank.pending = 0
	profile.bank.lastTick = now
	for id in pairs(profile.bank.upgrades) do
		profile.bank.upgrades[id] = 0
	end
	-- skins preservadas além das vagas básicas do banco voltam ao inventário
	local deposited = BankMath.depositedItems(profile)
	for i = BankMath.slots(profile) + 1, #deposited do
		deposited[i].location = "inventory"
		deposited[i].depositedAt = nil
	end
	-- equipamentos além do limite
	local maxEquip = ProfileSchema.equipSlots(profile)
	local n = 0
	for _, item in pairs(profile.inventory) do
		if item.equipped then
			n = n + 1
			if n > maxEquip then
				item.equipped = false
			end
		end
	end

	if profile.rebirths >= 1 then
		profile.titles[R.TitleFirst] = true
	end
	if profile.rebirths >= 5 then
		profile.titles[R.TitleFifth] = true
	end
	local newAchievements = ProfileOps.checkAchievements(profile, now)
	logTx(profile, now, "rebirth", { n = profile.rebirths, removed = #removedDefs })
	return true, { rebirths = profile.rebirths, removedCount = #removedDefs, achievements = newAchievements }
end

return ProfileOps
