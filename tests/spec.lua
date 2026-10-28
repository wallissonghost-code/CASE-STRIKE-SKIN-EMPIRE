-- Testes de lógica (executados por tests/harness.py fora do Roblox).
-- Cobrem os testes obrigatórios 1–14 e 16 da especificação no nível da lógica do servidor.
-- Os itens 15, 17 e 18 exigem o Roblox Studio e estão no checklist manual (docs/TESTES.md).

local RarityConfig = shared_module("Config/RarityConfig")
local SkinDefinitions = shared_module("Config/SkinDefinitions")
local CaseDefinitions = shared_module("Config/CaseDefinitions")
local EconomyConfig = shared_module("Config/EconomyConfig")
local BankConfig = shared_module("Config/BankConfig")
local ProgressionConfig = shared_module("Config/ProgressionConfig")
local MissionDefinitions = shared_module("Config/MissionDefinitions")
local FeatureFlags = shared_module("Config/FeatureFlags")
local UpgradeRecipes = shared_module("Config/UpgradeRecipes")
local Probability = shared_module("Logic/Probability")
local BankMath = shared_module("Logic/BankMath")
local Wealth = shared_module("Logic/Wealth")
local ProfileSchema = shared_module("Logic/ProfileSchema")
local ProfileOps = shared_module("Logic/ProfileOps")
local ClientView = shared_module("Logic/ClientView")
local AutoOpen = shared_module("Logic/AutoOpen")
local LeaderboardStats = shared_module("Logic/LeaderboardStats")
local Format = shared_module("Util/Format")
local TimeUtil = shared_module("Util/TimeUtil")

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
		print("  ok   " .. name)
	else
		failed = failed + 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then
		error((msg or "esperado igual") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
	end
end
local function near(a, b, tol, msg)
	if math.abs(a - b) > (tol or 1e-9) then
		error((msg or "esperado próximo") .. ": " .. tostring(a) .. " vs " .. tostring(b), 2)
	end
end
local function truthy(v, msg)
	if not v then
		error(msg or "esperado verdadeiro", 2)
	end
end

local NOW = 1793000000 -- 2026-10-26 (dentro do Festival das Sombras)
local function seqRng(values)
	local i = 0
	return function()
		i = i + 1
		return values[((i - 1) % #values) + 1]
	end
end
local function lcgRng(seed)
	local s = seed
	return function()
		s = (s * 16807) % 2147483647
		return s / 2147483647
	end
end
local function ctx(now, rng)
	return { now = now or NOW, rng = rng or lcgRng(42) }
end
local function fresh(now)
	local p = ProfileSchema.new(now or NOW)
	ProfileSchema.validate(p, now or NOW)
	return p
end
local function count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end
local function firstUid(p)
	for uid in pairs(p.inventory) do
		return uid
	end
end
local function giveItem(p, defId)
	local uid = "i" .. p.nextUid
	p.nextUid = p.nextUid + 1
	p.inventory[uid] = { uid = uid, defId = defId, obtainedAt = NOW, favorite = false, equipped = false, location = "inventory", upgrades = {} }
	p.discovered[defId] = NOW
	return uid
end
local function skinOf(caseId, rarity)
	for _, s in ipairs(SkinDefinitions.ByCase[caseId]) do
		if s.rarity == rarity then
			return s
		end
	end
end

-- serialização equivalente às restrições do DataStore (JSON): sem funções, sem tabelas mistas
local function serialize(v, path)
	path = path or "perfil"
	local tv = type(v)
	if tv == "number" then
		assert(v == v, "NaN em " .. path)
		return string.format("%.17g", v)
	elseif tv == "string" then
		return string.format("%q", v)
	elseif tv == "boolean" then
		return tostring(v)
	elseif tv == "table" then
		local n = #v
		local keys = 0
		for _ in pairs(v) do
			keys = keys + 1
		end
		local parts = {}
		if n > 0 and keys == n then
			for i = 1, n do
				parts[i] = serialize(v[i], path .. "[" .. i .. "]")
			end
			return "{" .. table.concat(parts, ",") .. "}"
		end
		local sorted = {}
		for k in pairs(v) do
			assert(type(k) == "string", "chave não textual em tabela de dicionário: " .. path .. "." .. tostring(k))
			table.insert(sorted, k)
		end
		table.sort(sorted)
		for _, k in ipairs(sorted) do
			table.insert(parts, "[" .. string.format("%q", k) .. "]=" .. serialize(v[k], path .. "." .. k))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("tipo não serializável em " .. path .. ": " .. tv)
end
local function roundTrip(p)
	local s = serialize(p)
	return assert(load("return " .. s))(), s
end

print("== Conteúdo e configuração ==")

test("60 skins e 12 caixas com 5 skins cada", function()
	eq(SkinDefinitions.Count, 60)
	eq(#CaseDefinitions.List, 12)
	for _, c in ipairs(CaseDefinitions.List) do
		eq(#c.drops, 5, "skins na caixa " .. c.id)
	end
	local cats = {}
	for _, s in ipairs(SkinDefinitions.List) do
		cats[s.category] = true
		truthy(RarityConfig.Rarities[s.rarity], "raridade inválida")
		truthy(s.value >= 1, "valor")
	end
	for _, c in ipairs({ "Pistol", "SMG", "Rifle", "Sniper", "Knife" }) do
		truthy(cats[c], "categoria ausente " .. c)
	end
end)

test("preços e níveis das 12 caixas", function()
	local expect = { starter = 10, urban = 25, tactical = 75, neon = 150, shadow = 300, chrome = 600, phantom = 1200, elite = 2500, diamond = 5000, royal = 12000, mythic = 30000, infinity = 100000 }
	for id, price in pairs(expect) do
		eq(CaseDefinitions.ById[id].price, price, id)
	end
	local levels = { starter = 1, neon = 5, elite = 20, royal = 40, infinity = 75 }
	for id, lvl in pairs(levels) do
		eq(CaseDefinitions.ById[id].requiredLevel, lvl, "nível " .. id)
	end
	eq(EconomyConfig.StartingCredits, 500)
end)

test("validador de RNG não encontra erros", function()
	local DropValidator = shared_module("Logic/DropValidator")
	local errors = DropValidator.validate()
	eq(#errors, 0, table.concat(errors, "; "))
end)

test("validador detecta skin inexistente e peso inválido", function()
	local DropValidator = shared_module("Logic/DropValidator")
	local c = CaseDefinitions.ById.starter
	local saved = c.drops[1]
	c.drops[1] = { skinId = "nao_existe", rarity = "Common", weight = -1 }
	local errors, bad = DropValidator.validate()
	c.drops[1] = saved
	truthy(#errors >= 2 and bad.starter, "erros detectados")
end)

test("probabilidades somam 100% com e sem sorte", function()
	for _, c in ipairs(CaseDefinitions.List) do
		for _, luck in ipairs({ 0, 0.05, 0.25, 5 }) do
			local t = Probability.computeTable(c, luck)
			local sum = 0
			for _, e in ipairs(t) do
				sum = sum + e.probability
			end
			near(sum, 1, 1e-12, "soma " .. c.id)
			local shown = Probability.displayPercents(t, 3)
			local s2 = 0
			for _, v in ipairs(shown) do
				s2 = s2 + v
			end
			near(s2, 100, 1e-6, "percentuais exibidos")
		end
	end
end)

test("sorte aumenta raras, mantém soma e respeita teto", function()
	local c = CaseDefinitions.ById.phantom
	local base = Probability.byRarity(Probability.computeTable(c, 0))
	local lucky = Probability.byRarity(Probability.computeTable(c, 0.25))
	local capped = Probability.byRarity(Probability.computeTable(c, 99))
	truthy(lucky.Secret > base.Secret and lucky.Uncommon < base.Uncommon)
	near(capped.Secret, lucky.Secret, 1e-12, "teto de sorte")
end)


test("valor esperado de cada caixa entre 80% e 95% do preço", function()
	for _, c in ipairs(CaseDefinitions.List) do
		local ev = Probability.expectedValue(Probability.computeTable(c, 0), SkinDefinitions)
		local ratio = ev / c.price
		truthy(ratio > 0.8 and ratio < 0.95, c.id .. " EV/preço = " .. ratio)
	end
end)

test("sorteio segue as probabilidades (simulação 200k)", function()
	local c = CaseDefinitions.ById.urban
	local t = Probability.computeTable(c, 0)
	local rng = lcgRng(7)
	local hits = {}
	local N = 200000
	for _ = 1, N do
		local e = Probability.pick(t, rng())
		hits[e.rarity] = (hits[e.rarity] or 0) + 1
	end
	local expected = Probability.byRarity(t)
	for r, p in pairs(expected) do
		near((hits[r] or 0) / N, p, 0.004, "frequência " .. r)
	end
end)

print("== Testes obrigatórios ==")

test("[1] inventário persiste (ida e volta no formato do DataStore)", function()
	local p = fresh()
	local ok = ProfileOps.openCases(p, ctx(), "urban", 5, {})
	truthy(ok)
	local back = roundTrip(p)
	ProfileSchema.migrate(back, NOW)
	local issues = ProfileSchema.validate(back, NOW)
	eq(#issues, 0, "problemas de integridade: " .. table.concat(issues, "; "))
	eq(count(back.inventory), 5)
	for uid, item in pairs(p.inventory) do
		eq(back.inventory[uid].defId, item.defId)
	end
	eq(back.credits, p.credits)
	eq(back.nextUid, p.nextUid)
end)

test("[1b] ClientView é serializável (sem tabelas mistas)", function()
	local p = fresh()
	ProfileOps.openCases(p, ctx(), "urban", 5, {})
	serialize(ClientView.build(p, NOW, "Tester"))
end)

test("[2] cada abertura entrega o prêmio sorteado", function()
	local c = CaseDefinitions.ById.urban
	local t = Probability.computeTable(c, ProfileOps.activeLuck(fresh(), NOW))
	local rolls = { 0.01, 0.5, 0.9, 0.9999, 0.7 }
	local p = fresh()
	local ok, res = ProfileOps.openCases(p, ctx(NOW, seqRng(rolls)), "urban", 5, {})
	truthy(ok)
	for i, r in ipairs(res.results) do
		eq(r.defId, Probability.pick(t, rolls[i]).skinId, "prêmio " .. i)
		eq(p.inventory[r.uid].defId, r.defId, "item no inventário")
	end
end)

test("[3] sem cobranças duplicadas", function()
	local p = fresh()
	local before = p.credits
	ProfileOps.openCases(p, ctx(), "urban", 1, {})
	eq(p.credits, before - 25)
	ProfileOps.openCases(p, ctx(), "urban", 5, {})
	eq(p.credits, before - 25 - 125)
	eq(p.stats.casesOpened, 6)
end)

test("[4] abertura múltipla é atômica", function()
	local p = fresh()
	p.credits = 240 -- não paga 10 Urban (250)
	local snapshot = serialize(p)
	local ok, code = ProfileOps.openCases(p, ctx(), "urban", 10, {})
	eq(ok, false)
	eq(code, "insufficient_credits")
	eq(serialize(p), snapshot, "perfil não pode mudar em falha")
	p.credits = 250
	ok = ProfileOps.openCases(p, ctx(), "urban", 10, {})
	truthy(ok)
	eq(count(p.inventory), 10)
	eq(p.credits, 0)
	local ok2, code2 = ProfileOps.openCases(p, ctx(), "urban", 3, {})
	eq(ok2, false)
	eq(code2, "invalid_quantity")
end)

test("[4b] inventário cheio bloqueia sem perda", function()
	local p = fresh()
	p.credits = 100000
	for _ = 1, EconomyConfig.InventoryCapacity - 3 do
		giveItem(p, "urban_01")
	end
	local before = p.credits
	local ok, code = ProfileOps.openCases(p, ctx(), "urban", 5, {})
	eq(ok, false)
	eq(code, "inventory_full")
	eq(p.credits, before)
end)

test("[4c] caixas grátis e bloqueio por nível", function()
	local p = fresh()
	p.level = 3
	p.freeCases.tactical = 1
	local before = p.credits
	local ok, res = ProfileOps.openCases(p, ctx(), "tactical", 1, { useFree = true })
	truthy(ok and res.usedFree)
	eq(p.credits, before)
	eq(p.freeCases.tactical, nil)
	local ok2, code2 = ProfileOps.openCases(p, ctx(), "infinity", 1, {})
	eq(ok2, false)
	eq(code2, "level_locked")
end)

test("[5] abertura automática pode ser interrompida e tem limites", function()
	local s = AutoOpen.new()
	s:start("urban", 1, 1000)
	truthy(s:check("urban", 1, 1000))
	s:record(1000)
	local ok, why = s:check("urban", 1, 1000.5)
	eq(ok, false)
	eq(why, "auto_too_fast")
	s:stop("user")
	ok, why = s:check("urban", 1, 1010)
	eq(ok, false)
	eq(why, "auto_inactive")
	s:start("urban", 1, 2000)
	local t = 2000
	for _ = 1, EconomyConfig.Opening.AutoMaxOpensPerSession do
		t = t + 2
		truthy(s:check("urban", 1, t))
		s:record(t)
	end
	ok, why = s:check("urban", 1, t + 2)
	eq(why, "auto_limit_opens")
	eq(s.active, false)
	s:start("urban", 1, 0)
	ok, why = s:check("urban", 1, EconomyConfig.Opening.AutoMaxSessionSeconds + 1)
	eq(why, "auto_limit_time")
end)

test("[6] venda não duplica créditos", function()
	local p = fresh()
	local uid = giveItem(p, "phantom_05") -- secreta
	local value = SkinDefinitions.ById.phantom_05.value
	local before = p.credits
	local okV, codeV = ProfileOps.sellItems(p, ctx(), { uid }, false, false)
	eq(codeV, "valuable_locked", "secreta exige confirmação")
	eq(p.credits, before)
	local ok = ProfileOps.sellItems(p, ctx(), { uid }, false, true)
	truthy(ok)
	eq(p.credits, before + value)
	local ok2, code2 = ProfileOps.sellItems(p, ctx(), { uid }, false, true)
	eq(ok2, false)
	eq(code2, "invalid_item")
	eq(p.credits, before + value)
	-- lista com uid repetido é rejeitada inteira
	local u2 = giveItem(p, "urban_01")
	local ok3 = ProfileOps.sellItems(p, ctx(), { u2, u2 }, false)
	eq(ok3, false)
	truthy(p.inventory[u2])
end)

test("[6b] favoritos exigem confirmação explícita", function()
	local p = fresh()
	local uid = giveItem(p, "urban_01")
	ProfileOps.setFavorite(p, ctx(), uid, true)
	local ok, code = ProfileOps.sellItems(p, ctx(), { uid }, false)
	eq(ok, false)
	eq(code, "favorite_locked")
	truthy(p.inventory[uid])
	truthy(ProfileOps.sellItems(p, ctx(), { uid }, true))
end)

test("[7] banco não duplica skins", function()
	local p = fresh()
	local uid = giveItem(p, "neon_05")
	local n = count(p.inventory)
	truthy(ProfileOps.deposit(p, ctx(), uid))
	eq(count(p.inventory), n)
	eq(p.inventory[uid].location, "bank")
	local ok, code = ProfileOps.deposit(p, ctx(), uid)
	eq(ok, false)
	eq(code, "item_in_bank")
	ok, code = ProfileOps.sellItems(p, ctx(), { uid }, true)
	eq(code, "item_in_bank")
	ok, code = ProfileOps.applyUpgrade(p, ctx(), uid, "finish")
	eq(code, "item_in_bank")
	truthy(ProfileOps.withdraw(p, ctx(), uid))
	eq(p.inventory[uid].location, "inventory")
	eq(count(p.inventory), n)
	-- vagas
	for _ = 1, BankConfig.BaseSlots do
		truthy(ProfileOps.deposit(p, ctx(), giveItem(p, "urban_01")))
	end
	ok, code = ProfileOps.deposit(p, ctx(), uid)
	eq(code, "bank_full")
end)

test("[8] renda calculada corretamente", function()
	local p = fresh()
	local def = SkinDefinitions.ById.elite_04
	local uid = giveItem(p, def.id)
	ProfileOps.deposit(p, ctx(NOW), uid)
	local rate = BankMath.baseIncome(def) * BankMath.efficiency(p)
	near(BankMath.totalRate(p), rate, 1e-12)
	local expected = BankConfig.K * def.value ^ BankConfig.Exponent * RarityConfig.Rarities[def.rarity].bankMultiplier
	near(rate, math.min(expected, BankConfig.MaxIncomePerSkin), 1e-12, "fórmula")
	BankMath.settle(p, NOW + 100)
	near(p.bank.pending, math.min(rate * 100, BankMath.storageCap(p)), 1e-9)
	local before = p.credits
	local ok, res = ProfileOps.claimBank(p, ctx(NOW + 100))
	truthy(ok)
	eq(p.credits, before + res.credits)
	truthy(p.bank.pending < 1 and p.bank.pending >= 0, "sobra fracionária")
	local ok2 = ProfileOps.claimBank(p, ctx(NOW + 100))
	eq(ok2, false)
end)

test("[8b] retornos decrescentes e teto por skin", function()
	local cheap = BankMath.baseIncome({ value = 100, rarity = "Common" })
	local rich = BankMath.baseIncome({ value = 10000, rarity = "Common" })
	truthy(rich / 10000 < cheap / 100, "proporcionalmente menor")
	eq(BankMath.baseIncome({ value = 1e12, rarity = "Secret" }), BankConfig.MaxIncomePerSkin)
end)

test("[9] banco respeita limite de produção offline e teto do cofre", function()
	local p = fresh()
	p.bank.upgrades.storage = 8
	local uid = giveItem(p, "infinity_05")
	ProfileOps.deposit(p, ctx(NOW), uid)
	local rate = BankMath.totalRate(p)
	BankMath.settle(p, NOW + 48 * 3600)
	near(p.bank.pending, math.min(rate * BankConfig.MaxOfflineSeconds, BankMath.storageCap(p)), 1e-6)
	local p2 = fresh()
	ProfileOps.deposit(p2, ctx(NOW), giveItem(p2, "infinity_05"))
	BankMath.settle(p2, NOW + 48 * 3600)
	eq(p2.bank.pending, BankMath.storageCap(p2), "teto do cofre")
	-- relógio voltando não gera créditos
	local before = p2.bank.pending
	BankMath.settle(p2, NOW)
	eq(p2.bank.pending, before)
end)

test("[10] patrimônio não conta itens duas vezes", function()
	local p = fresh()
	p.credits = 1000
	local a = giveItem(p, "neon_05")
	local b = giveItem(p, "phantom_05")
	local c = giveItem(p, "urban_01")
	ProfileOps.equip(p, ctx(), a)
	ProfileOps.deposit(p, ctx(), b)
	local w = Wealth.compute(p)
	local va = SkinDefinitions.ById.neon_05.value
	local vb = SkinDefinitions.ById.phantom_05.value
	local vc = SkinDefinitions.ById.urban_01.value
	eq(w.netWorth, 1000 + va + vb + vc)
	eq(w.equipValue, va)
	eq(w.bankValue, vb)
	BankMath.settle(p, NOW + 3600)
	local w2 = Wealth.compute(p)
	eq(w2.netWorth, w.netWorth + math.floor(p.bank.pending), "pendente entra uma vez")
	local before = w2.netWorth
	ProfileOps.claimBank(p, ctx(NOW + 3600))
	local w3 = Wealth.compute(p)
	truthy(math.abs(w3.netWorth - before) <= 0, "resgate não altera o patrimônio")
end)

test("[11] renascimento preserva o prometido", function()
	local p = fresh()
	p.level = 25
	p.credits = 60000
	local keepEpic = giveItem(p, "urban_05")
	local keepRare = giveItem(p, "urban_04")
	local keepFav = giveItem(p, "urban_01")
	ProfileOps.setFavorite(p, ctx(), keepFav, true)
	local lose = giveItem(p, "urban_02")
	p.achievements.a_open1 = NOW
	p.collectionsClaimed.urban = true
	local ok, code = ProfileOps.rebirth(p, ctx(), "renascer")
	eq(ok, false)
	eq(code, "confirmation_required")
	local preview = ProfileOps.rebirthPreview(p, NOW)
	truthy(preview.canRebirth)
	eq(preview.keepItems.count, 3)
	eq(preview.loseItems.count, 1)
	truthy(ProfileOps.rebirth(p, ctx(), "RENASCER"))
	truthy(p.inventory[keepEpic] and p.inventory[keepFav] and p.inventory[keepRare], "raras preservadas")
	eq(p.inventory[lose], nil)
	truthy(p.discovered.urban_02, "índice preservado")
	truthy(p.achievements.a_open1 and p.collectionsClaimed.urban)
	eq(p.rebirths, 1)
	truthy(p.level <= 2, "nível reiniciado (a conquista de renascimento concede XP)")
	eq(p.credits, EconomyConfig.StartingCredits)
	truthy(p.titles.renascido)
	local ok2, code2 = ProfileOps.rebirth(p, ctx(), "RENASCER")
	eq(code2, "rebirth_locked")
end)

test("[12] oficina não consome recursos sem entregar o resultado", function()
	local p = fresh()
	local uid = giveItem(p, "urban_04")
	p.credits = 10000
	local snapshot = serialize(p)
	local ok, code = ProfileOps.applyUpgrade(p, ctx(), uid, "holo")
	eq(code, "insufficient_materials")
	eq(serialize(p), snapshot)
	p.materials.scrap = 50
	p.materials.pigment = 10
	local quote = ProfileOps.upgradeQuote(p, uid, "holo")
	local before = p.credits
	ok = ProfileOps.applyUpgrade(p, ctx(), uid, "holo")
	truthy(ok)
	truthy(p.inventory[uid].upgrades.holo, "resultado entregue")
	eq(p.credits, before - quote.credits)
	eq(p.materials.scrap, 40)
	eq(p.materials.pigment, 7)
	local ok2, code2 = ProfileOps.applyUpgrade(p, ctx(), uid, "holo")
	eq(code2, "already_upgraded")
	local ok3, code3 = ProfileOps.applyUpgrade(p, ctx(), giveItem(p, "urban_01"), "gold")
	eq(code3, "rarity_too_low")
end)

test("[13] missões não podem ser resgatadas repetidamente", function()
	local p = fresh()
	ProfileOps.refreshPeriods(p, NOW)
	local id = p.missions.daily[1]
	local def = MissionDefinitions.ById[id]
	local ok, code = ProfileOps.claimMission(p, ctx(), id)
	eq(code, "mission_incomplete")
	p.missions.progress[id] = def.target
	truthy(ProfileOps.claimMission(p, ctx(), id))
	local snap = serialize(p)
	ok, code = ProfileOps.claimMission(p, ctx(), id)
	eq(code, "already_claimed")
	eq(serialize(p), snap)
	-- missão de outro dia não está ativa
	local other
	for _, m in ipairs(MissionDefinitions.Daily) do
		local active = false
		for _, a in ipairs(p.missions.daily) do
			if a == m.id then
				active = true
			end
		end
		if not active then
			other = m.id
		end
	end
	ok, code = ProfileOps.claimMission(p, ctx(), other)
	eq(code, "mission_inactive")
	-- no dia seguinte as diárias reiniciam
	ProfileOps.refreshPeriods(p, NOW + 86400)
	eq(p.missions.claimed[id] ~= true or p.missions.daily[1] ~= id, true)
end)

test("[13b] progresso de missão por eventos", function()
	local p = fresh()
	ProfileOps.refreshPeriods(p, NOW)
	p.missions.daily = { "d_open10", "d_sell3common", "d_deposit1" }
	p.missions.progress = { d_open10 = 0, d_sell3common = 0, d_deposit1 = 0 }
	p.credits = 1000
	ProfileOps.openCases(p, ctx(), "urban", 10, {})
	eq(p.missions.progress.d_open10, 10)
	truthy(ProfileOps.claimMission(p, ctx(), "d_open10"))
	eq(p.freeCases.urban, 1)
end)

test("[13c] presente diário e de nível sem resgate duplicado", function()
	local p = fresh()
	truthy(ProfileOps.claimDaily(p, ctx(NOW)))
	local ok, code = ProfileOps.claimDaily(p, ctx(NOW + 60))
	eq(code, "already_claimed")
	truthy(ProfileOps.claimDaily(p, ctx(NOW + 86400)))
	eq(p.rewards.dailyStreak, 2)
	truthy(ProfileOps.claimDaily(p, ctx(NOW + 86400 * 3)))
	eq(p.rewards.dailyStreak, 1, "sequência reinicia ao pular dia")
	ok, code = ProfileOps.claimLevelReward(p, ctx(), 5)
	eq(code, "level_locked")
	p.level = 5
	truthy(ProfileOps.claimLevelReward(p, ctx(), 5))
	ok, code = ProfileOps.claimLevelReward(p, ctx(), 5)
	eq(code, "already_claimed")
	truthy(p.rewards.levelClaimed["5"])
end)

test("[13d] coleção e conquistas com resgate único", function()
	local p = fresh()
	for _, s in ipairs(SkinDefinitions.ByCase.urban) do
		p.discovered[s.id] = NOW
	end
	ProfileOps.checkAchievements(p, NOW)
	truthy(p.achievements.a_col1)
	truthy(ProfileOps.claimCollection(p, ctx(), "urban"))
	truthy(p.cosmetics.frame_urban and p.cosmetics.showcase_urban and p.cosmetics.variant_urban, "cosméticos da coleção")
	truthy(p.titles.grafiteiro, "título da coleção")
	local ok, code = ProfileOps.claimCollection(p, ctx(), "urban")
	eq(code, "already_claimed")
	ok, code = ProfileOps.claimCollection(p, ctx(), "tactical")
	eq(code, "collection_incomplete")
	truthy(ProfileOps.claimAchievement(p, ctx(), "a_col1"))
	ok, code = ProfileOps.claimAchievement(p, ctx(), "a_col1")
	eq(code, "already_claimed")
	ok, code = ProfileOps.claimAchievement(p, ctx(), "a_col12")
	eq(code, "achievement_locked")
end)

test("[14] rankings consistentes com o perfil", function()
	local p = fresh()
	p.credits = 500
	local uid = giveItem(p, "phantom_05")
	ProfileOps.deposit(p, ctx(NOW), uid)
	BankMath.settle(p, NOW + 3600)
	local s = LeaderboardStats.compute(p)
	eq(s.netWorth, 500 + SkinDefinitions.ById.phantom_05.value + math.floor(p.bank.pending))
	local before = s.netWorth
	local ok, res = ProfileOps.claimBank(p, ctx(NOW + 3600))
	truthy(ok)
	eq(LeaderboardStats.compute(p).netWorth, before, "renda contada uma única vez")
	truthy(s.bankIncome > 0, "ranking de renda")
	eq(s.unique, 1)
end)

test("[16] PvP, monstros e combate bloqueados", function()
	for _, k in ipairs({ "PvP", "MonsterCombat", "Bosses", "Shooting", "DamageAndCombat", "SkinCrashGambling", "PlayerTrading", "PaidRandomItems" }) do
		eq(FeatureFlags[k], false, k)
	end
end)

print("== Integridade, XP e utilitários ==")

test("integridade corrige perfil corrompido", function()
	local p = fresh()
	p.credits = -50
	p.inventory.i7 = { uid = "i7", defId = "nao_existe", location = "inventory" }
	p.inventory.i3 = { uid = "i3", defId = "urban_01", location = "foguete", upgrades = {} }
	p.nextUid = 10
	p.bank.lastTick = NOW + 99999
	for _ = 1, 6 do
		local uid = giveItem(p, "urban_01")
		p.inventory[uid].location = "bank"
	end
	p.nextUid = 1
	local issues = ProfileSchema.validate(p, NOW)
	truthy(#issues >= 4)
	eq(p.credits, 0)
	eq(p.inventory.i7, nil)
	eq(p.inventory.i3.location, "inventory")
	truthy(p.nextUid > 15)
	local inBank = 0
	for _, it in pairs(p.inventory) do
		if it.location == "bank" then
			inBank = inBank + 1
		end
	end
	eq(inBank, BankMath.slots(p))
	eq(p.bank.lastTick, NOW)
end)

test("XP repetitivo tem limite diário", function()
	local p = fresh()
	p.credits = 1e6
	p.level = 50
	local Progression = shared_module("Logic/Progression")
	local total = 0
	for _ = 1, 500 do
		total = total + Progression.addXp(p, 2, "open", NOW)
	end
	eq(total, ProgressionConfig.DailyXpCaps.open)
	truthy(Progression.addXp(p, 2, "open", NOW + 86400) == 2, "reinicia no dia seguinte")
end)

test("curva de XP gradual", function()
	local prev = 0
	for l = 1, 99 do
		local x = ProgressionConfig.xpForLevel(l)
		truthy(x > prev)
		prev = x
	end
end)

test("melhorias do banco: custo progressivo e limite", function()
	local p = fresh()
	p.credits = 1e9
	p.level = 100
	local last = 0
	for i = 1, BankConfig.Upgrades.slots.maxLevel do
		local ok, res = ProfileOps.buyBankUpgrade(p, ctx(), "slots")
		truthy(ok)
		truthy(res.cost > last)
		last = res.cost
	end
	local ok, code = ProfileOps.buyBankUpgrade(p, ctx(), "slots")
	eq(code, "max_level")
	eq(BankMath.slots(p), BankConfig.BaseSlots + BankConfig.Upgrades.slots.maxLevel)
end)

test("equipamentos respeitam vagas", function()
	local p = fresh()
	for i = 1, EconomyConfig.BaseEquipSlots do
		truthy(ProfileOps.equip(p, ctx(), giveItem(p, "urban_01")))
	end
	local ok, code = ProfileOps.equip(p, ctx(), giveItem(p, "urban_02"))
	eq(code, "equip_full")
end)

test("sorte temporária expira e a de usos é consumida", function()
	local p = fresh()
	ProfileOps.grantLuck(p, "luck_daily", NOW)
	ProfileOps.grantLuck(p, "luck_mission", NOW)
	local total = ProfileOps.activeLuck(p, NOW)
	truthy(total >= 0.13 - 1e-9, "sorte somada " .. total)
	p.credits = 10000
	ProfileOps.openCases(p, ctx(NOW), "urban", 10, {})
	ProfileOps.openCases(p, ctx(NOW), "urban", 10, {})
	ProfileOps.openCases(p, ctx(NOW), "urban", 10, {})
	local _, list = ProfileOps.activeLuck(p, NOW + 3600)
	for _, e in ipairs(list) do
		truthy(e.id ~= "luck_daily" and e.id ~= "luck_mission", "expirou: " .. e.id)
	end
end)

test("missões determinísticas por dia", function()
	local a = MissionDefinitions.dailyFor(20000)
	local b = MissionDefinitions.dailyFor(20000)
	eq(table.concat(a, ","), table.concat(b, ","))
	eq(#a, MissionDefinitions.DailyCount)
	local w = MissionDefinitions.weeklyFor(2900)
	eq(#w, MissionDefinitions.WeeklyCount)
end)

test("formatação", function()
	eq(Format.int(1234567), "1.234.567")
	eq(Format.short(1500), "1,5 mil")
	eq(Format.short(2000000), "2 mi")
	eq(Format.percent(0.12345, 2), "12,35%")
	eq(TimeUtil.weekIndex(345600), 0)
end)

test("preço da oficina é determinístico", function()
	local r = UpgradeRecipes.ById.finish
	eq(UpgradeRecipes.creditCost(r, 100), 55)
end)

print("== Novidades V4 ==")

local AttributeConfig = shared_module("Config/AttributeConfig")

test("×25 exige o atributo Limite de abertura múltipla", function()
	local p = fresh()
	p.credits = 100000
	local ok, code = ProfileOps.openCases(p, ctx(), "starter", 25, {})
	eq(code, "quantity_locked")
	eq(p.credits, 100000)
	p.level = 15
	truthy(ProfileOps.buyAttribute(p, ctx(), "multiOpen"))
	local ok2, res = ProfileOps.openCases(p, ctx(), "starter", 25, {})
	truthy(ok2, tostring(res))
	eq(#res.results, 25)
end)

test("atributos: limite máximo, requisito e custo progressivo", function()
	local p = fresh()
	p.credits = 1e9
	local ok, code = ProfileOps.buyAttribute(p, ctx(), "luck")
	eq(code, "level_locked")
	p.level = 100
	local last = 0
	for _ = 1, AttributeConfig.Attributes.luck.maxLevel do
		local okB, res = ProfileOps.buyAttribute(p, ctx(), "luck")
		truthy(okB)
		truthy(res.cost > last)
		last = res.cost
	end
	ok, code = ProfileOps.buyAttribute(p, ctx(), "luck")
	eq(code, "max_level")
	local total = ProfileOps.activeLuck(p, NOW)
	truthy(total >= 0.10 - 1e-9, "sorte do atributo aplicada")
	local info = ProfileOps.attributeInfo(p, "luck")
	eq(info.level, info.maxLevel)
	eq(info.nextBenefit, nil)
end)

test("atributos vinculados alteram a mesma melhoria do banco", function()
	local p = fresh()
	p.credits = 1e9
	p.level = 100
	truthy(ProfileOps.buyAttribute(p, ctx(), "bankCapacity"))
	eq(p.bank.upgrades.slots, 1)
	eq(ProfileOps.attributeLevel(p, "bankCapacity"), 1)
	truthy(ProfileOps.buyBankUpgrade(p, ctx(), "efficiency"))
	eq(ProfileOps.attributeLevel(p, "bankEfficiency"), 1)
end)

test("bônus de XP e títulos por nível", function()
	local p = fresh()
	p.attributes.xpBonus = 10
	local Progression = shared_module("Logic/Progression")
	local got = Progression.addXp(p, 100, nil, NOW)
	eq(got, 150)
	local p2 = fresh()
	ProfileOps._giveXp(p2, 60000, nil, NOW)
	truthy(p2.level >= 15)
	truthy(p2.titles.colecionador and p2.titles.especialista, "títulos de nível")
end)

test("conquistas concedem XP", function()
	local p = fresh()
	p.stats.casesOpened = 1
	ProfileOps.checkAchievements(p, NOW)
	truthy(p.achievements.a_open1)
	truthy(p.xp > 0 or p.level > 1)
end)

test("limite offline aumenta com a melhoria", function()
	local p = fresh()
	p.bank.upgrades.storage = 8
	ProfileOps.deposit(p, ctx(NOW), giveItem(p, "elite_04"))
	local base = BankMath.offlineCap(p)
	p.bank.upgrades.offline = 2
	eq(BankMath.offlineCap(p), base + 4 * 3600)
	local rate = BankMath.totalRate(p)
	BankMath.settle(p, NOW + 100 * 3600)
	near(p.bank.pending, math.min(rate * (base + 4 * 3600), BankMath.storageCap(p)), 1e-6)
end)

test("showroom: limite de vagas e depósito remove a exposição", function()
	local p = fresh()
	local uids = {}
	for i = 1, EconomyConfig.ShowcaseSlots do
		uids[i] = giveItem(p, "urban_01")
		truthy(ProfileOps.setShowcase(p, ctx(), uids[i], true))
	end
	local ok, code = ProfileOps.setShowcase(p, ctx(), giveItem(p, "urban_02"), true)
	eq(code, "showcase_full")
	truthy(ProfileOps.deposit(p, ctx(), uids[1]))
	eq(p.inventory[uids[1]].showcase, nil)
	eq(ProfileOps.showcaseCount(p), EconomyConfig.ShowcaseSlots - 1)
end)

test("variante exclusiva da coleção exige coleção resgatada", function()
	local p = fresh()
	local uid = giveItem(p, "starter_01")
	local ok, code = ProfileOps.applyCollectionVariant(p, ctx(), uid)
	eq(code, "cosmetic_locked")
	for _, s in ipairs(SkinDefinitions.ByCase.starter) do
		p.discovered[s.id] = NOW
	end
	truthy(ProfileOps.claimCollection(p, ctx(), "starter"))
	truthy(ProfileOps.applyCollectionVariant(p, ctx(), uid))
	truthy(p.inventory[uid].upgrades.colVariant)
end)

test("caixas de níveis altos bloqueadas e liberadas pelo nível", function()
	local p = fresh()
	p.credits = 1e7
	local ok, code = ProfileOps.openCases(p, ctx(), "royal", 1, {})
	eq(code, "level_locked")
	p.level = 40
	truthy(ProfileOps.openCases(p, ctx(), "royal", 1, {}))
end)

test("evolução não trava sem créditos: caixa Starter acessível e presente diário", function()
	local p = fresh()
	p.credits = 0
	truthy(ProfileOps.claimDaily(p, ctx()))
	truthy(p.credits >= CaseDefinitions.ById.starter.price)
end)

print(string.format("\n%d passaram, %d falharam", passed, failed))
return failed == 0
