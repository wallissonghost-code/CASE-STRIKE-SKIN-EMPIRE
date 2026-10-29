-- Income: produção das criaturas calculada por horário (sem laço por segundo).
-- Cada criatura guarda moedas no próprio pedestal desde `since` até o limite do cofre.
-- Funciona igual online e offline: ao voltar, o jogador encontra o que foi produzido
-- (no máximo o tempo do cofre). Relógio voltando no tempo não gera moedas.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local EventConfig = require(Shared.Config.EventConfig)

local Income = {}

function Income.upgradeLevel(profile, id)
	return (profile.upgrades and profile.upgrades[id]) or 0
end

function Income.baseIncome(creature)
	local s = GameConfig.SpeciesById[creature.s]
	local m = GameConfig.Mutations[creature.m]
	if not s or not m then
		return 0
	end
	return s.income * m.mult
end

function Income.value(creature)
	local s = GameConfig.SpeciesById[creature.s]
	local m = GameConfig.Mutations[creature.m]
	if not s or not m then
		return 0
	end
	return s.price * m.mult
end

function Income.sellPrice(creature)
	return math.floor(Income.value(creature) * GameConfig.SellRate)
end

-- multiplicador permanente (renascimentos)
function Income.multiplier(profile)
	return 1 + (profile.rebirths or 0) * GameConfig.Rebirth.IncomeBonusPer
end

function Income.rate(profile, creature)
	return Income.baseIncome(creature) * Income.multiplier(profile)
end

function Income.storageSeconds(profile)
	return GameConfig.Base.StorageSeconds + Income.upgradeLevel(profile, "storage") * GameConfig.Upgrades.storage.perLevel
end

local function overlap(a1, a2, b1, b2)
	return math.max(0, math.min(a2, b2) - math.max(a1, b1))
end

-- segundos "efetivos" em [from, to] somando bônus de renda: poção de renda e evento "Renda em Dobro"
function Income.boostedSeconds(profile, from, to)
	local secs = to - from
	if secs <= 0 then
		return 0
	end
	local potionEnd = (profile.activePotions and profile.activePotions.renda) or 0
	if potionEnd > from then
		local potionStart = (profile.potionStarts and profile.potionStarts.renda) or from
		secs = secs + overlap(from, to, potionStart, potionEnd) * (GameConfig.Potions.renda.incomeMult - 1)
	end
	for _, w in ipairs(EventConfig.windows(from, to, "income")) do
		secs = secs + overlap(from, to, w.startsAt, w.endsAt) * (w.incomeMult - 1)
	end
	return secs
end

-- multiplicador de renda neste instante (para mostrar na interface)
function Income.currentBoost(profile, now)
	local mult = 1
	if profile.activePotions and (profile.activePotions.renda or 0) > now then
		mult = mult + (GameConfig.Potions.renda.incomeMult - 1)
	end
	local ev = EventConfig.at(now)
	if ev and ev.kind == "income" then
		mult = mult + (ev.incomeMult - 1)
	end
	return mult
end

-- moedas guardadas no pedestal desta criatura agora
function Income.pending(profile, creature, now)
	local since = creature.since or now
	if now <= since then
		return math.min(creature.banked or 0, Income.cap(profile, creature))
	end
	local rate = Income.rate(profile, creature)
	local storage = Income.storageSeconds(profile)
	local cap = rate * storage
	-- depois de `storage` segundos efetivos o cofre já está cheio: limita a janela
	local produced = (creature.banked or 0) + rate * Income.boostedSeconds(profile, since, math.min(now, since + storage))
	return math.min(cap, produced)
end

-- guarda o valor produzido até agora e recomeça a contagem (antes de mudar regras de renda)
function Income.bank(profile, creature, now)
	creature.banked = Income.pending(profile, creature, now)
	creature.since = now
end

function Income.cap(profile, creature)
	return Income.rate(profile, creature) * Income.storageSeconds(profile)
end

function Income.totalPending(profile, now)
	local sum = 0
	for _, c in pairs(profile.creatures) do
		sum = sum + Income.pending(profile, c, now)
	end
	return sum
end

-- renda por segundo (sem bônus temporários)
function Income.totalRate(profile)
	local sum = 0
	for _, c in pairs(profile.creatures) do
		sum = sum + Income.rate(profile, c)
	end
	return sum
end

function Income.netWorth(profile)
	local v = profile.coins
	for _, c in pairs(profile.creatures) do
		v = v + Income.value(c)
	end
	return v
end

return Income
