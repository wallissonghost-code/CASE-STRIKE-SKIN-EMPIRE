-- ProfileSchema: formato do perfil salvo, migração e validação de integridade.
-- Um único documento por jogador => compra, venda, coleta e roubo são atômicos.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)

local ProfileSchema = {}

ProfileSchema.Version = 1

function ProfileSchema.new(now)
	return {
		version = ProfileSchema.Version,
		createdAt = now,
		coins = GameConfig.StartingCoins,
		creatures = {}, -- [uid] = { uid, s (espécie), m (mutação), pad, since, at, origin, protectedUntil }
		nextUid = 1,
		upgrades = { slots = 0, storage = 0, shield = 0, speed = 0 },
		potions = { sorte = 0, renda = 0, velocidade = 0 },
		activePotions = {}, -- [id] = horário em que termina
		potionStarts = {}, -- [id] = início da ativação contínua atual (renda exata por período)
		index = {}, -- ["especie:mutacao"] = horário da descoberta
		missions = { day = -1, list = {}, progress = {}, claimed = {} },
		gifts = { lastDay = -1, streak = 0 },
		milestones = {},
		rebirths = 0,
		stats = {
			conveyorBought = 0,
			hatched = 0,
			stolen = 0,
			defended = 0,
			lostToThieves = 0,
			coinsCollected = 0,
			sold = 0,
		},
		settings = { reduceEffects = false },
	}
end

local function isNumber(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- completa campos que faltam (perfis antigos ou corrompidos)
function ProfileSchema.migrate(profile, now)
	local fresh = ProfileSchema.new(now)
	for k, v in pairs(fresh) do
		if profile[k] == nil or type(profile[k]) ~= type(v) then
			profile[k] = v
		end
	end
	for _, group in ipairs({ "upgrades", "potions", "stats", "settings" }) do
		for k, v in pairs(fresh[group]) do
			if type(profile[group][k]) ~= type(v) then
				profile[group][k] = v
			end
		end
	end
	for _, k in ipairs({ "list", "progress", "claimed" }) do
		if type(profile.missions[k]) ~= "table" then
			profile.missions[k] = {}
		end
	end
	profile.version = ProfileSchema.Version
	return profile
end

function ProfileSchema.slots(profile)
	return GameConfig.Base.StartSlots + (profile.upgrades.slots or 0) * GameConfig.Upgrades.slots.perLevel
end

-- corrige valores impossíveis; retorna a lista de problemas encontrados
function ProfileSchema.validate(profile, now)
	local issues = {}
	if not isNumber(profile.coins) or profile.coins < 0 then
		table.insert(issues, "moedas inválidas")
		profile.coins = 0
	end
	profile.coins = math.min(math.floor(profile.coins), GameConfig.MaxCoins)
	for id, u in pairs(GameConfig.Upgrades) do
		local l = profile.upgrades[id]
		if not isNumber(l) or l < 0 or l > u.maxLevel then
			table.insert(issues, "melhoria " .. id)
			profile.upgrades[id] = math.max(0, math.min(u.maxLevel, math.floor(isNumber(l) and l or 0)))
		end
	end
	for id in pairs(GameConfig.Potions) do
		local n = profile.potions[id]
		if not isNumber(n) or n < 0 then
			profile.potions[id] = 0
			table.insert(issues, "poção " .. id)
		end
	end
	if not isNumber(profile.rebirths) or profile.rebirths < 0 then
		profile.rebirths = 0
		table.insert(issues, "renascimentos")
	end
	-- criaturas: espécie/mutação existentes, pedestal único dentro das vagas, horários válidos
	local slots = ProfileSchema.slots(profile)
	local usedPads = {}
	local list = {}
	for uid, c in pairs(profile.creatures) do
		if type(c) ~= "table" or not GameConfig.SpeciesById[c.s] or not GameConfig.Mutations[c.m] then
			table.insert(issues, "criatura inválida " .. tostring(uid))
			profile.creatures[uid] = nil
		else
			c.uid = uid
			if not isNumber(c.since) or c.since > now + 60 then
				c.since = now
			end
			if c.banked ~= nil and (not isNumber(c.banked) or c.banked < 0) then
				c.banked = 0
			end
			table.insert(list, c)
		end
	end
	table.sort(list, function(a, b)
		return (a.at or 0) < (b.at or 0)
	end)
	local overflow = {}
	for _, c in ipairs(list) do
		if isNumber(c.pad) and c.pad >= 1 and c.pad <= slots and not usedPads[c.pad] then
			usedPads[c.pad] = true
		else
			table.insert(overflow, c)
		end
	end
	for _, c in ipairs(overflow) do
		local free = nil
		for i = 1, slots do
			if not usedPads[i] then
				free = i
				break
			end
		end
		if free then
			c.pad = free
			usedPads[free] = true
		else
			-- mais criaturas que vagas (não deveria acontecer): vende pelo valor normal
			profile.creatures[c.uid] = nil
			local s = GameConfig.SpeciesById[c.s]
			profile.coins = profile.coins + math.floor(s.price * GameConfig.Mutations[c.m].mult * GameConfig.SellRate)
			table.insert(issues, "criatura sem vaga vendida " .. c.uid)
		end
	end
	if not isNumber(profile.nextUid) or profile.nextUid < 1 then
		profile.nextUid = 1
	end
	for uid in pairs(profile.creatures) do
		local n = tonumber(string.match(uid, "^c(%d+)$") or "")
		if n and n >= profile.nextUid then
			profile.nextUid = n + 1
		end
	end
	return issues
end

function ProfileSchema.creatureCount(profile)
	local n = 0
	for _ in pairs(profile.creatures) do
		n = n + 1
	end
	return n
end

function ProfileSchema.freePad(profile)
	local used = {}
	for _, c in pairs(profile.creatures) do
		used[c.pad] = true
	end
	for i = 1, ProfileSchema.slots(profile) do
		if not used[i] then
			return i
		end
	end
	return nil
end

return ProfileSchema
