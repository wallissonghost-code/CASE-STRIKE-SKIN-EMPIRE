-- BankMath: renda passiva calculada por timestamps (sem loop por skin).
-- A produção é liquidada ("settle") sempre que o banco muda ou é consultado.

local Shared = script.Parent.Parent
local BankConfig = require(Shared.Config.BankConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local ProgressionConfig = require(Shared.Config.ProgressionConfig)

local BankMath = {}

function BankMath.upgradeLevel(profile, id)
	return (profile.bank.upgrades and profile.bank.upgrades[id]) or 0
end

function BankMath.upgradeCost(id, currentLevel)
	local u = BankConfig.Upgrades[id]
	return math.floor(u.baseCost * (u.growth ^ currentLevel) + 0.5)
end

function BankMath.slots(profile)
	local rebirthSlots = math.floor((profile.rebirths or 0) / ProgressionConfig.Rebirth.ExtraBankSlotEvery)
	return BankConfig.BaseSlots + BankMath.upgradeLevel(profile, "slots") * BankConfig.Upgrades.slots.perLevel + rebirthSlots
end

-- tempo máximo de produção acumulada sem o jogador liquidar (offline)
function BankMath.offlineCap(profile)
	return BankConfig.MaxOfflineSeconds + BankMath.upgradeLevel(profile, "offline") * BankConfig.Upgrades.offline.perLevel
end

function BankMath.storageCap(profile)
	local lvl = BankMath.upgradeLevel(profile, "storage")
	return math.floor(BankConfig.BaseStorage * ((1 + BankConfig.Upgrades.storage.perLevel) ^ lvl) + 0.5)
end

-- multiplicador de eficiência: melhorias + bônus moderado de renascimento
function BankMath.efficiency(profile)
	local up = BankMath.upgradeLevel(profile, "efficiency") * BankConfig.Upgrades.efficiency.perLevel
	local rb = math.min(
		(profile.rebirths or 0) * ProgressionConfig.Rebirth.BankEfficiencyPerRebirth,
		ProgressionConfig.Rebirth.BankEfficiencyMax
	)
	return 1 + up + rb
end

-- renda base (sem eficiência) de uma definição de skin, com retornos decrescentes e limites
function BankMath.baseIncome(def)
	local rarity = RarityConfig.Rarities[def.rarity]
	local income = BankConfig.K * (def.value ^ BankConfig.Exponent) * rarity.bankMultiplier
	return math.max(BankConfig.MinIncomePerSkin, math.min(income, BankConfig.MaxIncomePerSkin))
end

function BankMath.itemIncome(profile, item)
	local def = SkinDefinitions.ById[item.defId]
	if not def then
		return 0
	end
	return BankMath.baseIncome(def) * BankMath.efficiency(profile)
end

function BankMath.depositedItems(profile)
	local list = {}
	for _, item in pairs(profile.inventory) do
		if item.location == "bank" then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		return (a.depositedAt or 0) < (b.depositedAt or 0)
	end)
	return list
end

function BankMath.totalRate(profile)
	local rate = 0
	for _, item in pairs(profile.inventory) do
		if item.location == "bank" then
			rate = rate + BankMath.itemIncome(profile, item)
		end
	end
	return rate
end

-- Liquida a produção desde bank.lastTick até now.
-- Limita o intervalo ao limite offline (BankMath.offlineCap) e o acumulado ao teto do cofre.
-- Retorna o quanto foi produzido nesta liquidação.
function BankMath.settle(profile, now)
	local bank = profile.bank
	local last = bank.lastTick or now
	local dt = now - last
	if dt < 0 then
		dt = 0 -- relógio voltou: não produz, apenas reancora
	end
	local maxDt = BankMath.offlineCap(profile)
	if dt > maxDt then
		dt = maxDt
	end
	local cap = BankMath.storageCap(profile)
	local before = bank.pending or 0
	local produced = 0
	if before < cap then
		produced = BankMath.totalRate(profile) * dt
		bank.pending = math.min(cap, before + produced)
		produced = bank.pending - before
	end
	bank.lastTick = now
	return produced
end

return BankMath
