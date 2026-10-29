-- Testes de lógica do MUTANT FACTORY (módulos compartilhados reais, sem Roblox).

local GameConfig = shared_module("Config/GameConfig")
local ProgressConfig = shared_module("Config/ProgressConfig")
local EventConfig = shared_module("Config/EventConfig")
local MapConfig = shared_module("Config/MapConfig")
local Odds = shared_module("Logic/Odds")
local Income = shared_module("Logic/Income")
local ProfileSchema = shared_module("Logic/ProfileSchema")
local ProfileOps = shared_module("Logic/ProfileOps")
local ClientView = shared_module("Logic/ClientView")
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
	if math.abs(a - b) > (tol or 1e-6) then
		error((msg or "esperado próximo") .. ": " .. tostring(a) .. " vs " .. tostring(b), 2)
	end
end
local function truthy(v, msg)
	if not v then
		error(msg or "esperado verdadeiro", 2)
	end
end

-- horário fora de qualquer evento (início de período + 10 min)
local T0 = 1793000000
T0 = math.floor(T0 / EventConfig.Period) * EventConfig.Period + 600
assert(EventConfig.at(T0) == nil)

local seed = 7
local function rng()
	seed = (seed * 16807) % 2147483647
	return seed / 2147483647
end
local function ctx(now, locked)
	return { now = now or T0, rng = rng, locked = locked }
end
local function newProfile(now)
	local p = ProfileSchema.new(now or T0)
	ProfileOps.refreshPeriods(p, now or T0)
	return p
end
local function count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end
local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local o = {}
	for k, v in pairs(t) do
		o[k] = deepCopy(v)
	end
	return o
end
local function give(p, speciesId, mutationId, now)
	local ok, r = ProfileOps.buyFromConveyor(p, ctx(now), { speciesId = speciesId, mutationId = mutationId or "normal", price = 0 })
	assert(ok, tostring(r))
	return r.creature
end

print("== Lógica ==")

test("conteúdo: 16 espécies, 6 mutações, ovos válidos", function()
	eq(#GameConfig.Species, 16)
	eq(#GameConfig.MutationOrder, 6)
	for _, s in ipairs(GameConfig.Species) do
		truthy(GameConfig.Rarities[s.rarity], "raridade de " .. s.id)
		truthy(s.income > 0 and s.price > 0)
	end
	for _, id in ipairs(GameConfig.EggOrder) do
		truthy(GameConfig.Eggs[id])
	end
end)

test("chances de espécies e mutações somam 100% (com e sem sorte)", function()
	for _, luck in ipairs({ 0, 0.25, 1, 5 }) do
		local sp = Odds.speciesTable(GameConfig.Conveyor.RarityWeights, luck)
		local mu = Odds.mutationTable(luck)
		local a, b = 0, 0
		for _, e in ipairs(sp) do
			a = a + e.p
		end
		for _, e in ipairs(mu) do
			b = b + e.p
		end
		near(a, 1, 1e-9)
		near(b, 1, 1e-9)
		local shown = 0
		for _, v in ipairs(Odds.displayPercents(sp, 2)) do
			shown = shown + v
		end
		near(shown, 100, 1e-6, "exibição soma 100")
	end
end)

test("sorte aumenta raras e mutações, nunca muda comuns para cima", function()
	local base = Odds.byRarity(Odds.speciesTable(GameConfig.Conveyor.RarityWeights, 0))
	local lucky = Odds.byRarity(Odds.speciesTable(GameConfig.Conveyor.RarityWeights, 0.5))
	truthy(lucky.Mythic > base.Mythic and lucky.Legendary > base.Legendary)
	truthy(lucky.Common < base.Common)
	local m0 = Odds.mutationTable(0)[1].p
	local m1 = Odds.mutationTable(0.5)[1].p
	truthy(m1 < m0, "normal fica menos provável")
	-- sorte acima do teto é limitada
	local capped = Odds.speciesTable(GameConfig.Conveyor.RarityWeights, 50)
	local max = Odds.speciesTable(GameConfig.Conveyor.RarityWeights, GameConfig.Luck.Max)
	near(capped[1].p, max[1].p, 1e-12)
end)

test("evento de mutação multiplica só a mutação dele", function()
	local ev = EventConfig.force("chuva_dourada", T0, 60)
	local withEv = Odds.mutationTable(0, ev)
	EventConfig.override = nil
	local without = Odds.mutationTable(0)
	truthy(withEv[2].p > without[2].p * 3, "dourada bem mais comum")
	near(withEv[2].weight, without[2].weight * 5, 1e-9)
	eq(withEv[3].weight, without[3].weight)
end)

test("valor esperado dos ovos fica perto do preço (sem sorte)", function()
	for _, id in ipairs(GameConfig.EggOrder) do
		local egg = GameConfig.Eggs[id]
		local ratio = Odds.expectedEggValue(egg, 0) / egg.price
		truthy(ratio > 0.85 and ratio < 1.15, id .. " razão " .. ratio)
	end
end)

test("sorteio real segue as chances (100 mil ovos)", function()
	local sp = Odds.speciesTable(GameConfig.Eggs.basico.rarityWeights, 0)
	local hits = {}
	local n = 100000
	for _ = 1, n do
		local e = Odds.pick(sp, rng())
		hits[e.rarity] = (hits[e.rarity] or 0) + 1
	end
	local exp = Odds.byRarity(sp)
	for r, p in pairs(exp) do
		near((hits[r] or 0) / n, p, 0.01, r)
	end
end)

test("saldo inicial e base inicial", function()
	local p = newProfile()
	eq(p.coins, 300)
	eq(ProfileSchema.slots(p), 8)
	eq(count(p.creatures), 0)
	eq(#p.missions.list, 3)
end)

test("comprar na esteira cobra, ocupa pedestal e registra no índice", function()
	local p = newProfile()
	local ok, r = ProfileOps.buyFromConveyor(p, ctx(), { speciesId = "gosminha", mutationId = "dourada", price = 50 })
	truthy(ok)
	eq(p.coins, 250)
	eq(r.creature.pad, 1)
	truthy(r.isNew)
	truthy(p.index["gosminha:dourada"])
	eq(p.stats.conveyorBought, 1)
end)

test("sem moedas ou sem vaga: nada muda", function()
	local p = newProfile()
	local before = deepCopy(p)
	local ok, code = ProfileOps.buyFromConveyor(p, ctx(), { speciesId = "dragosma", mutationId = "normal", price = 13500 })
	eq(ok, false)
	eq(code, "insufficient_coins")
	eq(p.coins, before.coins)
	for _ = 1, 8 do
		give(p, "gosminha")
	end
	p.coins = 1e6
	local ok2, code2 = ProfileOps.hatchEgg(p, ctx(), "basico")
	eq(ok2, false)
	eq(code2, "base_full")
	eq(p.coins, 1e6)
	eq(count(p.creatures), 8)
end)

test("ovo: cobra o preço, entrega 1 criatura, ovo lendário exige renascimento", function()
	local p = newProfile()
	p.coins = 1e6
	local ok, r = ProfileOps.hatchEgg(p, ctx(), "raro")
	truthy(ok)
	eq(p.coins, 1e6 - 10000)
	eq(count(p.creatures), 1)
	truthy(GameConfig.SpeciesById[r.creature.s])
	local ok2, code = ProfileOps.hatchEgg(p, ctx(), "lendario")
	eq(ok2, false)
	eq(code, "egg_locked")
	p.rebirths = 1
	truthy((ProfileOps.hatchEgg(p, ctx(), "lendario")))
	local bad = ProfileOps.hatchEgg(p, ctx(), "inexistente")
	eq(bad, false)
end)

test("produção por horário, limite do cofre e relógio voltando", function()
	local p = newProfile()
	local c = give(p, "bolhudo") -- 2/s
	near(Income.pending(p, c, T0 + 100), 200, 1e-6)
	near(Income.pending(p, c, T0 + 10 * 3600), 2 * 1800, 1e-6, "cofre de 30 min")
	eq(Income.pending(p, c, T0 - 500), 0, "relógio para trás não gera moedas")
	p.rebirths = 2
	near(Income.pending(p, c, T0 + 100), 400, 1e-6, "renascimentos multiplicam renda")
end)

test("coletar paga tudo de uma vez e zera os pedestais", function()
	local p = newProfile()
	give(p, "gosminha")
	give(p, "bolhudo")
	local ok, r = ProfileOps.collectAll(p, ctx(T0 + 60))
	truthy(ok)
	eq(r.coins, 180)
	eq(p.coins, 300 + 180)
	local ok2, code = ProfileOps.collectAll(p, ctx(T0 + 60))
	eq(ok2, false)
	eq(code, "nothing_to_collect")
end)

test("renda offline: volta depois de 8 horas e recebe só o cofre", function()
	local p = newProfile()
	give(p, "espinhoso") -- 7/s
	p.upgrades.storage = 2 -- 30 + 60 min
	local ok, r = ProfileOps.collectAll(p, ctx(T0 + 8 * 3600))
	truthy(ok)
	eq(r.coins, 7 * 5400)
end)

test("poção de renda e evento Renda em Dobro contam só no período certo", function()
	local p = newProfile()
	local c = give(p, "gosminha") -- 1/s
	p.potions.renda = 1
	truthy((ProfileOps.activatePotion(p, ctx(T0 + 100), "renda")))
	-- 100 s normais + 100 s com ×1,5
	near(Income.pending(p, c, T0 + 200), 100 + 150, 1e-6)
	-- evento de renda: procura a próxima janela e mede dentro dela
	local p2 = newProfile()
	local c2 = give(p2, "gosminha")
	local w
	local t = T0
	while not w do
		local e = EventConfig.at(t)
		if e and e.kind == "income" then
			w = e
		end
		t = t + 60
	end
	c2.since = w.startsAt
	near(Income.pending(p2, c2, w.startsAt + 100), 200, 1e-6, "dobro durante o evento")
	c2.since = w.endsAt
	near(Income.pending(p2, c2, w.endsAt + 100), 100, 1e-6, "normal depois")
end)

test("vender: 50% do valor + guardado; valiosa exige confirmação; carregada não vende", function()
	local p = newProfile()
	local c = give(p, "olhudo", "dourada") -- valor 7200
	local ok, r = ProfileOps.sell(p, ctx(T0 + 10), c.uid)
	truthy(ok)
	eq(r.coins, 3600)
	eq(r.collected, 1100)
	eq(p.coins, 300 + 3600 + 1100)
	local leg = give(p, "rei_gosma")
	local okL, codeL = ProfileOps.sell(p, ctx(), leg.uid)
	eq(okL, false)
	eq(codeL, "valuable_locked")
	local okC, codeC = ProfileOps.sell(p, ctx(T0, { [leg.uid] = true }), leg.uid, true)
	eq(okC, false)
	eq(codeC, "being_stolen")
	truthy((ProfileOps.sell(p, ctx(), leg.uid, true)))
	eq(count(p.creatures), 0)
end)

test("melhorias: custo crescente, efeito e nível máximo", function()
	local p = newProfile()
	p.coins = 1e12
	local c1 = GameConfig.upgradeCost("slots", 0)
	truthy((ProfileOps.buyUpgrade(p, ctx(), "slots")))
	eq(ProfileSchema.slots(p), 10)
	truthy(GameConfig.upgradeCost("slots", 1) > c1)
	for _ = 2, GameConfig.Upgrades.slots.maxLevel do
		truthy((ProfileOps.buyUpgrade(p, ctx(), "slots")))
	end
	eq(ProfileSchema.slots(p), 20)
	local ok, code = ProfileOps.buyUpgrade(p, ctx(), "slots")
	eq(ok, false)
	eq(code, "max_level")
	truthy((ProfileOps.buyUpgrade(p, ctx(), "shield")))
	eq(ProfileOps.shieldSeconds(p), 70)
	truthy((ProfileOps.buyUpgrade(p, ctx(), "speed")))
	eq(ProfileOps.walkSpeed(p, T0, false), 17)
	eq(ProfileOps.walkSpeed(p, T0, true), 13)
end)

test("cofre maior não apaga nem duplica a produção guardada", function()
	local p = newProfile()
	p.coins = 1e9
	local c = give(p, "gosminha")
	local before = Income.pending(p, c, T0 + 5000) -- cheio: 1800
	near(before, 1800, 1e-6)
	truthy((ProfileOps.buyUpgrade(p, ctx(T0 + 5000), "storage")))
	near(Income.pending(p, c, T0 + 5000), 1800, 1e-6)
	near(Income.pending(p, c, T0 + 5100), 1900, 1e-6)
end)

test("poções: comprar com moedas, ativar, acumular até o máximo", function()
	local p = newProfile()
	p.coins = 1e6
	truthy((ProfileOps.buyPotion(p, ctx(), "sorte")))
	eq(p.potions.sorte, 1)
	eq(p.coins, 1e6 - 20000)
	truthy((ProfileOps.activatePotion(p, ctx(), "sorte")))
	local luck = ProfileOps.luck(p, T0 + 10)
	near(luck, 0.25, 1e-9)
	p.potions.sorte = 10
	for _ = 1, 5 do
		ProfileOps.activatePotion(p, ctx(), "sorte")
	end
	eq(p.activePotions.sorte, T0 + 3600, "limite de 1 hora acumulada")
	local ok, code = ProfileOps.activatePotion(p, ctx(), "sorte")
	eq(ok, false)
	eq(code, "potion_max")
	local ok2, code2 = ProfileOps.activatePotion(p, ctx(), "velocidade")
	eq(code2, "no_potion")
end)

test("roubo: entrega move a criatura, vítima recebe o que estava guardado", function()
	local victim, thief = newProfile(), newProfile()
	local c = give(victim, "dragosma", "diamante")
	local okCan = ProfileOps.canSteal(victim, thief, c.uid, T0 + 30)
	truthy(okCan)
	local ok, r = ProfileOps.completeSteal(victim, thief, c.uid, T0 + 30)
	truthy(ok)
	eq(count(victim.creatures), 0)
	eq(count(thief.creatures), 1)
	eq(r.creature.s, "dragosma")
	eq(r.creature.m, "diamante")
	eq(victim.coins, 300 + 150 * 4 * 30, "vítima recebe a produção guardada")
	eq(r.creature.since, T0 + 30, "ladrão começa do zero")
	eq(thief.stats.stolen, 1)
	eq(victim.stats.lostToThieves, 1)
	truthy(thief.index["dragosma:diamante"])
end)

test("roubo: protegida por 3 min, base cheia ou criatura inexistente bloqueiam sem alterar", function()
	local a, b = newProfile(), newProfile()
	local c = give(a, "gosminha")
	truthy((ProfileOps.completeSteal(a, b, c.uid, T0)))
	local stolen
	for _, x in pairs(b.creatures) do
		stolen = x
	end
	local snapA, snapB = deepCopy(a), deepCopy(b)
	local ok, code = ProfileOps.completeSteal(b, a, stolen.uid, T0 + 60)
	eq(ok, false)
	eq(code, "protected")
	truthy((ProfileOps.canSteal(b, a, stolen.uid, T0 + 181)), "depois de 3 min pode")
	for _ = 1, 8 do
		give(a, "gosminha")
	end
	local ok2, code2 = ProfileOps.completeSteal(b, a, stolen.uid, T0 + 400)
	eq(code2, "base_full")
	eq(count(b.creatures), 1)
	local ok3, code3 = ProfileOps.completeSteal(b, a, "c999", T0 + 400)
	eq(code3, "invalid_creature")
	eq(snapB.coins, b.coins)
end)

test("missões: progresso pelos eventos, resgate único e recompensa escala com a renda", function()
	local p = newProfile()
	local id = p.missions.list[1]
	local def = ProgressConfig.MissionById[id]
	local ok0, code0 = ProfileOps.claimMission(p, ctx(), id)
	eq(code0, "not_ready")
	ProfileOps.emit(p, T0, def.event, def.target)
	for _ = 1, 4 do
		give(p, "olhudo") -- 55/s cada
	end
	local coins = p.coins
	local ok, r = ProfileOps.claimMission(p, ctx(), id)
	truthy(ok)
	local expected = math.max(def.reward.coins, math.floor(220 * 60 * def.reward.incomeMinutes))
	eq(p.coins - coins, expected)
	local ok2, code2 = ProfileOps.claimMission(p, ctx(), id)
	eq(code2, "already_claimed")
	local ok3, code3 = ProfileOps.claimMission(p, ctx(), "m_inexistente")
	eq(code3, "invalid_mission")
end)

test("missões mudam por dia e são iguais para todos", function()
	local d = TimeUtil.dayIndex(T0)
	local a = ProfileOps.pickMissions(d)
	local b = ProfileOps.pickMissions(d)
	eq(table.concat(a, ","), table.concat(b, ","))
	local p = newProfile()
	ProfileOps.emit(p, T0, "hatch", 1)
	ProfileOps.refreshPeriods(p, T0 + 86400)
	eq(p.missions.day, d + 1)
	eq(count(p.missions.progress), 0, "progresso zera no dia seguinte")
end)

test("presente diário: um por dia, sequência e recomeço", function()
	local p = newProfile()
	truthy((ProfileOps.claimGift(p, ctx())))
	eq(p.gifts.streak, 1)
	local ok, code = ProfileOps.claimGift(p, ctx(T0 + 60))
	eq(code, "already_claimed")
	truthy((ProfileOps.claimGift(p, ctx(T0 + 86400))))
	eq(p.gifts.streak, 2)
	eq(p.potions.velocidade, 1)
	truthy((ProfileOps.claimGift(p, ctx(T0 + 86400 * 4))))
	eq(p.gifts.streak, 1, "perdeu dias: recomeça")
end)

test("marcos do índice: só com combinações suficientes e uma vez", function()
	local p = newProfile()
	local ok, code = ProfileOps.claimMilestone(p, ctx(), "idx5")
	eq(code, "not_ready")
	for _, m in ipairs({ "normal", "dourada", "diamante", "radioativa", "vazio" }) do
		give(p, "gosminha", m)
	end
	eq(ProfileOps.indexCount(p), 5)
	truthy((ProfileOps.claimMilestone(p, ctx(), "idx5")))
	eq(p.potions.sorte, 1)
	local ok2, code2 = ProfileOps.claimMilestone(p, ctx(), "idx5")
	eq(code2, "already_claimed")
end)

test("renascer: confirmação, custo, reinicia moedas/criaturas e mantém índice e melhorias", function()
	local p = newProfile()
	give(p, "rei_gosma")
	p.upgrades.slots = 2
	local cost = GameConfig.rebirthCost(1)
	p.coins = cost - 1
	local _, code = ProfileOps.rebirth(p, ctx(), "RENASCER")
	eq(code, "rebirth_locked")
	p.coins = cost
	local _, code2 = ProfileOps.rebirth(p, ctx(), "renascer")
	eq(code2, "confirmation_required")
	local _, code3 = ProfileOps.rebirth(p, ctx(T0, { c1 = true }), "RENASCER")
	eq(code3, "being_stolen")
	truthy((ProfileOps.rebirth(p, ctx(), "RENASCER")))
	eq(p.rebirths, 1)
	eq(p.coins, 300)
	eq(count(p.creatures), 0)
	truthy(p.index["rei_gosma:normal"])
	eq(p.upgrades.slots, 2)
	near(Income.multiplier(p), 1.5, 1e-9)
	near((ProfileOps.luck(p, T0)), 0.05, 1e-9)
end)

test("perfil corrompido é reparado (moedas, pedestais duplicados, criaturas inválidas)", function()
	local p = newProfile()
	give(p, "gosminha")
	give(p, "bolhudo")
	p.creatures.c2.pad = 1 -- pedestal duplicado
	p.creatures.zz = { s = "nao_existe", m = "normal", pad = 3 }
	p.coins = -50
	p.upgrades.slots = 99
	p.potions.sorte = "x"
	local issues = ProfileSchema.validate(p, T0)
	truthy(#issues >= 4)
	eq(p.coins, 0)
	eq(p.upgrades.slots, GameConfig.Upgrades.slots.maxLevel)
	eq(p.creatures.zz, nil)
	truthy(p.creatures.c1.pad ~= p.creatures.c2.pad)
	eq(p.potions.sorte, 0)
	local old = { coins = 10 }
	ProfileSchema.migrate(old, T0)
	truthy(type(old.creatures) == "table" and type(old.upgrades) == "table" and old.coins == 10)
end)

test("agenda de eventos é fixa, 6 min a cada 30 min, e alterna tipos", function()
	local start = math.floor(T0 / EventConfig.Period) * EventConfig.Period
	local e = EventConfig.at(start + 10)
	truthy(e and e.endsAt == start + 360)
	eq(EventConfig.at(start + 400), nil)
	local n = EventConfig.nextEvent(start + 400)
	eq(n.startsAt, start + 1800)
	truthy(n.id ~= e.id)
end)

test("esteira: preço = preço da espécie × mutação", function()
	local o = ProfileOps.rollConveyor(T0, 0.0001, 0.0001)
	eq(o.speciesId, "gosminha")
	eq(o.mutationId, "normal")
	eq(o.price, 25)
	local o2 = ProfileOps.rollConveyor(T0, 0.9999999, 0.9999999)
	eq(o2.mutationId, "arcoiris")
	eq(o2.price, GameConfig.SpeciesById[o2.speciesId].price * 20)
end)

test("mapa: 6 bases, 20 pedestais dentro da base, sem sobreposição", function()
	eq(#MapConfig.Bases, 6)
	for b = 1, 6 do
		local seen = {}
		for i = 1, 20 do
			local x, z = MapConfig.padPosition(b, i)
			eq(MapConfig.baseAt(x, z), b, "pedestal " .. i .. " da base " .. b)
			local key = x .. "," .. z
			truthy(not seen[key])
			seen[key] = true
		end
		local sx, sz = MapConfig.toWorld(b, MapConfig.Terminal.spawn.lx, MapConfig.Terminal.spawn.lz)
		truthy(MapConfig.inDelivery(b, sx, sz))
	end
	eq(MapConfig.baseAt(0, 0), nil, "praça não é base")
end)

test("fotografia do cliente traz tudo e patrimônio sem dupla contagem", function()
	local p = newProfile()
	give(p, "olhudo")
	local v = ClientView.build(p, T0 + 10, { name = "Ana", baseIndex = 2, shieldUntil = T0 + 50 })
	eq(#v.creatures, 1)
	eq(v.netWorth, 300 + 3600)
	near(v.pending, 550, 1e-6)
	eq(v.slots, 8)
	eq(#v.upgrades, 4)
	eq(#v.missions, 3)
	eq(v.indexTotal, 96)
	eq(v.baseIndex, 2)
	ProfileOps.collectAll(p, ctx(T0 + 10))
	eq(Income.netWorth(p), 300 + 550 + 3600, "coletar não muda o patrimônio além do que entrou")
end)

print(string.format("\n%d passaram, %d falharam", passed, failed))
return failed == 0
