-- ProfileSchema: perfil padrão, migração de versões e verificação de integridade.
-- Um único documento por jogador contém inventário, banco e progresso,
-- o que torna cada operação atômica (sem duplicação entre documentos).

local Shared = script.Parent.Parent
local EconomyConfig = require(Shared.Config.EconomyConfig)
local BankConfig = require(Shared.Config.BankConfig)
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local CaseDefinitions = require(Shared.Config.CaseDefinitions)
local ProgressionConfig = require(Shared.Config.ProgressionConfig)
local AttributeConfig = require(Shared.Config.AttributeConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local PotionConfig = require(Shared.Config.PotionConfig)
local BankMath = require(Shared.Logic.BankMath)

local ProfileSchema = {}

ProfileSchema.Version = 3

function ProfileSchema.new(now)
	return {
		version = ProfileSchema.Version,
		createdAt = now,
		credits = EconomyConfig.StartingCredits,
		level = 1,
		xp = 0,
		rebirths = 0,
		nextUid = 1,
		inventory = {}, -- [uid] = item
		materials = { scrap = 0, pigment = 0, core = 0 },
		freeCases = {}, -- [caseId] = quantidade
		bank = {
			pending = 0,
			lastTick = now,
			upgrades = { slots = 0, efficiency = 0, storage = 0, offline = 0, display = 0 },
		},
		discovered = {}, -- [defId] = timestamp da primeira obtenção
		collectionsClaimed = {}, -- [collectionId] = true
		achievements = {}, -- [id] = timestamp de desbloqueio
		achievementsClaimed = {}, -- [id] = true
		titles = { novato = true },
		cosmetics = {}, -- [id] = true (molduras, vitrines e variantes de coleção)
		attributes = { luck = 0, xpBonus = 0, openSpeed = 0, multiOpen = 0 },
		zones = { zone1 = true }, -- zonas desbloqueadas
		potions = { luck = 0, xp = 0, income = 0 }, -- poções guardadas
		activePotions = { luck = 0, xp = 0, income = 0 }, -- horário (servidor) em que cada efeito termina
		stock = { day = -1, used = {} }, -- caixas de estoque limitado abertas no dia
		equippedTitle = "novato",
		missions = { day = -1, week = -1, daily = {}, weekly = {}, progress = {}, claimed = {} },
		eventProgress = { eventId = "", progress = {}, claimed = {} },
		rewards = { lastDailyDay = -1, dailyStreak = 0, levelClaimed = {} },
		luck = { modifiers = {} }, -- lista de { id, expiresAt?, usesLeft? }
		xpCaps = { day = -1, bySource = {} },
		stats = {
			casesOpened = 0,
			skinsSold = 0,
			creditsFromSales = 0,
			creditsSpentOnCases = 0,
			upgradesDone = 0,
			bankClaimedTotal = 0,
			bestDropValue = 0,
		},
		settings = { fastOpen = false, reduceEffects = false },
		txLog = {}, -- últimas transações (anel)
		txSeq = 0,
	}
end

local function isInteger(n)
	return type(n) == "number" and n == math.floor(n)
end

local function fillDefaults(target, defaults)
	for k, v in pairs(defaults) do
		if target[k] == nil then
			if type(v) == "table" then
				local copy = {}
				fillDefaults(copy, v)
				target[k] = copy
			else
				target[k] = v
			end
		elseif type(v) == "table" and type(target[k]) == "table" and k ~= "inventory" then
			fillDefaults(target[k], v)
		end
	end
end

-- Migra perfis antigos para a versão atual (estrutura preparada para expansão).
function ProfileSchema.migrate(profile, now)
	local defaults = ProfileSchema.new(now)
	fillDefaults(profile, defaults)
	profile.version = ProfileSchema.Version
	return profile
end

-- Verifica e corrige inconsistências. Retorna lista de problemas encontrados (strings).
function ProfileSchema.validate(profile, now)
	local issues = {}
	local function issue(msg)
		table.insert(issues, msg)
	end

	if type(profile.credits) ~= "number" or profile.credits ~= profile.credits then
		issue("saldo inválido; redefinido para 0")
		profile.credits = 0
	end
	if profile.credits < 0 then
		issue("saldo negativo corrigido")
		profile.credits = 0
	end
	if profile.credits > EconomyConfig.MaxCredits then
		issue("saldo acima do teto de segurança")
		profile.credits = EconomyConfig.MaxCredits
	end
	profile.credits = math.floor(profile.credits)

	if not isInteger(profile.level) or profile.level < 1 then
		issue("nível inválido")
		profile.level = 1
	end
	if profile.level > ProgressionConfig.MaxLevel then
		profile.level = ProgressionConfig.MaxLevel
	end
	if type(profile.xp) ~= "number" or profile.xp < 0 then
		profile.xp = 0
	end

	for k, v in pairs(profile.materials) do
		if type(v) ~= "number" or v < 0 then
			issue("material inválido: " .. tostring(k))
			profile.materials[k] = 0
		end
	end
	for caseId, n in pairs(profile.freeCases) do
		if not CaseDefinitions.ById[caseId] or type(n) ~= "number" or n <= 0 then
			profile.freeCases[caseId] = nil
		end
	end

	-- inventário: definições válidas, uids únicos, contador consistente
	local maxUidNum = 0
	local equippedCount = 0
	local bankCount = 0
	local removed = 0
	local toRemove = {}
	for uid, item in pairs(profile.inventory) do
		if type(item) ~= "table" or not SkinDefinitions.ById[item.defId] then
			table.insert(toRemove, uid)
		else
			if item.uid ~= uid then
				issue("uid divergente corrigido: " .. tostring(uid))
				item.uid = uid
			end
			if item.location ~= "inventory" and item.location ~= "bank" then
				item.location = "inventory"
			end
			if item.location == "bank" then
				item.equipped = false
				bankCount = bankCount + 1
			end
			if item.equipped then
				equippedCount = equippedCount + 1
			end
			item.upgrades = item.upgrades or {}
			local num = tonumber(string.match(uid, "^i(%d+)$") or "")
			if num and num > maxUidNum then
				maxUidNum = num
			end
			-- todas as skins possuídas contam como descobertas
			if not profile.discovered[item.defId] then
				profile.discovered[item.defId] = item.obtainedAt or now
			end
		end
	end
	for _, uid in ipairs(toRemove) do
		profile.inventory[uid] = nil
		removed = removed + 1
	end
	if removed > 0 then
		issue("itens com definição inexistente removidos: " .. removed)
	end
	if profile.nextUid <= maxUidNum then
		issue("contador de uid ajustado")
		profile.nextUid = maxUidNum + 1
	end

	-- banco: não pode ter mais skins que vagas; excedentes voltam ao inventário
	local slots = BankMath.slots(profile)
	if bankCount > slots then
		issue("skins além das vagas do banco devolvidas ao inventário")
		local deposited = BankMath.depositedItems(profile)
		for i = slots + 1, #deposited do
			deposited[i].location = "inventory"
			deposited[i].depositedAt = nil
		end
	end
	for id, u in pairs(BankConfig.Upgrades) do
		local lvl = profile.bank.upgrades[id] or 0
		if not isInteger(lvl) or lvl < 0 then
			lvl = 0
		end
		if lvl > u.maxLevel then
			lvl = u.maxLevel
		end
		profile.bank.upgrades[id] = lvl
	end
	if type(profile.bank.pending) ~= "number" or profile.bank.pending < 0 then
		profile.bank.pending = 0
	end
	local cap = BankMath.storageCap(profile)
	if profile.bank.pending > cap then
		profile.bank.pending = cap
	end
	if type(profile.bank.lastTick) ~= "number" or profile.bank.lastTick > now + 60 then
		issue("marcador de tempo do banco no futuro; reancorado")
		profile.bank.lastTick = now
	end

	-- atributos dentro dos limites (os vinculados ao banco ficam em bank.upgrades)
	for id, attr in pairs(AttributeConfig.Attributes) do
		if not attr.linkedBankUpgrade then
			local lvl = profile.attributes[id] or 0
			if not isInteger(lvl) or lvl < 0 then
				lvl = 0
			end
			if lvl > attr.maxLevel then
				issue("atributo acima do limite: " .. id)
				lvl = attr.maxLevel
			end
			profile.attributes[id] = lvl
		end
	end

	-- zonas, poções e estoque
	for id in pairs(profile.zones) do
		if not ZoneConfig.ById[id] then
			profile.zones[id] = nil
		end
	end
	profile.zones.zone1 = true
	for id in pairs(PotionConfig.Potions) do
		local n = profile.potions[id] or 0
		if not isInteger(n) or n < 0 then
			issue("poções inválidas: " .. id)
			n = 0
		end
		profile.potions[id] = n
		local e = profile.activePotions[id] or 0
		if type(e) ~= "number" or e < 0 then
			e = 0
		end
		-- efeito não pode terminar além do limite máximo a partir de agora
		if e > now + PotionConfig.Potions[id].maxStack then
			issue("efeito de poção além do limite: " .. id)
			e = now + PotionConfig.Potions[id].maxStack
		end
		profile.activePotions[id] = e
	end
	if type(profile.stock.used) ~= "table" then
		profile.stock = { day = -1, used = {} }
	end

	-- showroom: só skins no inventário e dentro do limite de vagas
	local shown = 0
	for _, item in pairs(profile.inventory) do
		if item.showcase then
			if item.location ~= "inventory" or shown >= EconomyConfig.ShowcaseSlots then
				item.showcase = nil
			else
				shown = shown + 1
			end
		end
	end

	-- equipamentos dentro do limite
	local maxEquip = ProfileSchema.equipSlots(profile)
	if equippedCount > maxEquip then
		issue("equipamentos acima do limite desmarcados")
		local n = 0
		for _, item in pairs(profile.inventory) do
			if item.equipped then
				n = n + 1
				if n > maxEquip then
					item.equipped = false
				end
			end
		end
	end

	for id in pairs(profile.titles) do
		if not ProgressionConfig.Titles[id] then
			profile.titles[id] = nil -- título removido do jogo
		end
	end
	if not profile.equippedTitle or not profile.titles[profile.equippedTitle] then
		profile.equippedTitle = "novato"
		profile.titles.novato = true
	end

	return issues
end

function ProfileSchema.equipSlots(profile)
	local rebirthBonus = math.floor((profile.rebirths or 0) / ProgressionConfig.Rebirth.ExtraEquipSlotEvery)
	local display = (profile.bank.upgrades and profile.bank.upgrades.display) or 0
	return math.min(EconomyConfig.MaxEquipSlots, EconomyConfig.BaseEquipSlots + display + rebirthBonus)
end

function ProfileSchema.itemCount(profile)
	local n = 0
	for _ in pairs(profile.inventory) do
		n = n + 1
	end
	return n
end

return ProfileSchema
