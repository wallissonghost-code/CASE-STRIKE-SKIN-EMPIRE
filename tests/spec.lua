-- Testes de lógica do MYSTERY MACHINE (sem Roblox): configs, sorteio, economia, inventário,
-- vitrine, melhorias, níveis, missões, presentes, coleção e reparo de perfis.

local MachineDefinitions = shared_module("MachineDefinitions")
local ItemDefinitions = shared_module("ItemDefinitions")
local RarityConfig = shared_module("RarityConfig")
local EconomyConfig = shared_module("EconomyConfig")
local UpgradeConfig = shared_module("UpgradeConfig")
local MissionDefinitions = shared_module("MissionDefinitions")
local Odds = shared_module("Logic/Odds")
local Levels = shared_module("Logic/Levels")
local ProfileSchema = shared_module("Logic/ProfileSchema")
local ProfileOps = shared_module("Logic/ProfileOps")
local ClientView = shared_module("Logic/ClientView")
local Format = shared_module("Util/Format")

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
local function truthy(v, msg)
	if not v then
		error(msg or "esperado verdadeiro", 2)
	end
end

local DAY = 86400
local NOW = 20000 * DAY + 3600 * 10 -- dia 20000, 10h UTC

-- gerador determinístico para os testes
local seed = 42
local function rand()
	seed = (seed * 16807) % 2147483647
	return seed / 2147483647
end

local function fresh()
	local p = ProfileSchema.new()
	ProfileOps.ensureDaily(p, NOW)
	return p
end

local function find(list, id)
	for _, x in ipairs(list) do
		if x.id == id then
			return x
		end
	end
end

print("== Lógica ==")

test("4 máquinas com preços e níveis do design", function()
	eq(#MachineDefinitions.List, 4)
	local expected = { common = { 25, 1 }, neon = { 150, 5 }, golden = { 750, 15 }, mystery = { 3000, 30 } }
	for id, e in pairs(expected) do
		eq(MachineDefinitions.get(id).price, e[1], id .. " preço")
		eq(MachineDefinitions.get(id).level, e[2], id .. " nível")
	end
end)

test("20 objetos, ids únicos, 6 raridades, cada objeto na pool da sua máquina de origem", function()
	eq(#ItemDefinitions.List, 20)
	eq(#RarityConfig.Order, 6)
	local seen = {}
	for _, m in ipairs(MachineDefinitions.List) do
		for _, entry in ipairs(m.pool) do
			local item = ItemDefinitions.get(entry.item)
			truthy(item, "item inexistente " .. entry.item)
			eq(item.machine, m.id, entry.item .. " máquina de origem")
			truthy(not seen[entry.item], "item repetido em pools")
			seen[entry.item] = true
		end
	end
	for _, item in ipairs(ItemDefinitions.List) do
		truthy(seen[item.id], item.id .. " fora de qualquer máquina")
		truthy(RarityConfig.get(item.rarity), item.id .. " raridade")
		truthy(item.value > 0)
	end
end)

test("chances de cada máquina somam exatamente 100% e a tela mostra as mesmas", function()
	for _, m in ipairs(MachineDefinitions.List) do
		truthy(math.abs(Odds.total(m) - 100) < 1e-9, m.id .. " soma " .. Odds.total(m))
		local shown = 0
		for _, row in ipairs(Odds.display(m.id)) do
			shown = shown + row.chance
			local entryChance
			for _, e in ipairs(m.pool) do
				if e.item == row.item then
					entryChance = e.chance
				end
			end
			truthy(math.abs(row.chance - entryChance) < 1e-9, "chance exibida difere da usada")
		end
		truthy(math.abs(shown - 100) < 1e-9)
	end
end)

test("sorteio: limites e distribuição em 200 mil aberturas seguem as chances", function()
	local m = MachineDefinitions.get("mystery")
	eq(Odds.pick(m, 0), "crystal_dragon")
	eq(Odds.pick(m, 0.99999), "secret_artifact")
	eq(Odds.pick(m, 0.995), "secret_artifact")
	eq(Odds.pick(m, 0.9949), "galactic_star")
	for _, id in ipairs({ "common", "mystery" }) do
		local machine = MachineDefinitions.get(id)
		local counts, n = {}, 200000
		for _ = 1, n do
			local item = Odds.pick(machine, rand())
			counts[item] = (counts[item] or 0) + 1
		end
		for _, e in ipairs(machine.pool) do
			local observed = (counts[e.item] or 0) * 100 / n
			local tolerance = math.max(0.15, e.chance * 0.05)
			truthy(math.abs(observed - e.chance) < tolerance, id .. "/" .. e.item .. " observado " .. observed .. " esperado " .. e.chance)
		end
	end
end)

test("valor médio de venda fica entre 85% e 97% do preço (máquina não é fonte infinita de moedas)", function()
	for _, m in ipairs(MachineDefinitions.List) do
		local ratio = Odds.expectedValue(m) / m.price
		truthy(ratio >= 0.85 and ratio <= 0.97, m.id .. " retorno " .. ratio)
	end
end)

test("níveis: curva, XP total e nível máximo", function()
	eq(Levels.level(0), 1)
	eq(Levels.totalFor(5), 350)
	eq(Levels.level(349), 4)
	eq(Levels.level(350), 5)
	local l, into, need = Levels.fromXp(Levels.totalFor(15) + 10)
	eq(l, 15)
	eq(into, 10)
	eq(need, Levels.xpToNext(15))
	eq(Levels.level(10 ^ 9), EconomyConfig.Levels.MaxLevel)
end)

test("perfil novo começa com 250 Coins e inventário vazio", function()
	local p = fresh()
	eq(p.coins, 250)
	eq(ProfileOps.itemCount(p), 0)
	eq(#p.daily.missions, 3)
end)

test("usar máquina: cobra o preço, entrega o objeto sorteado, registra descoberta e XP", function()
	local p = fresh()
	local r = ProfileOps.useMachine(p, "common", 0.1, NOW)
	truthy(r.ok, r.message)
	eq(r.itemId, "cup")
	eq(p.coins, 225)
	eq(p.inventory.cup, 1)
	truthy(p.discovered.cup)
	eq(r.isNew, true)
	eq(r.xp, RarityConfig.get("common").xp + EconomyConfig.OpenXp)
	eq(p.stats.opens, 1)
	local r2 = ProfileOps.useMachine(p, "common", 0.1, NOW)
	eq(r2.isNew, false)
	eq(r2.xp, EconomyConfig.OpenXp)
	eq(p.inventory.cup, 2)
end)

test("usar máquina: sem saldo, bloqueada por nível ou inventário cheio não altera nada", function()
	local p = fresh()
	p.coins = 24
	local r = ProfileOps.useMachine(p, "common", 0.5, NOW)
	eq(r.error, "coins")
	eq(p.coins, 24)
	eq(ProfileOps.itemCount(p), 0)
	p.coins = 10000
	eq(ProfileOps.useMachine(p, "neon", 0.5, NOW).error, "locked")
	eq(ProfileOps.useMachine(p, "nope", 0.5, NOW).error, "unknown")
	p.inventory.cup = ProfileOps.capacity(p)
	eq(ProfileOps.useMachine(p, "common", 0.5, NOW).error, "full")
	eq(p.coins, 10000)
	p.xp = Levels.totalFor(5)
	p.inventory.cup = 1
	truthy(ProfileOps.useMachine(p, "neon", 0.5, NOW).ok, "neon liberada no nível 5")
	eq(p.coins, 10000 - 150)
end)

test("XP por abertura tem limite diário (sem XP infinito repetindo)", function()
	local p = fresh()
	p.coins = 100000
	p.upgrades.capacity = UpgradeConfig.max("capacity")
	local before = p.xp
	for _ = 1, 60 do
		ProfileOps.useMachine(p, "common", 0.1, NOW)
	end
	local discoveryXp = RarityConfig.get("common").xp
	eq(p.xp - before, discoveryXp + EconomyConfig.OpenXpDailyCap)
	eq(p.daily.openXp, EconomyConfig.OpenXpDailyCap)
end)

test("subir de nível paga a recompensa uma única vez por nível", function()
	local p = fresh()
	local coins = p.coins
	local g = ProfileOps.addXp(p, Levels.totalFor(3))
	eq(#g.levels, 2)
	eq(p.coins, coins + EconomyConfig.levelReward(2) + EconomyConfig.levelReward(3))
	eq(p.levelRewarded, 3)
	-- mesmo que o XP fosse reduzido e subisse de novo, o nível já pago não paga outra vez
	p.xp = 0
	local c2 = p.coins
	ProfileOps.addXp(p, Levels.totalFor(3))
	eq(p.coins, c2)
end)

test("vender: valor do servidor, remove a cópia certa, não vende duas vezes", function()
	local p = fresh()
	p.inventory.cup = 1
	local r = ProfileOps.sell(p, "cup", 1, false, NOW)
	truthy(r.ok, r.message)
	eq(r.coins, 10)
	eq(p.coins, 260)
	eq(p.inventory.cup, nil)
	eq(ProfileOps.sell(p, "cup", 1, false, NOW).error, "missing")
	eq(p.coins, 260)
	eq(p.stats.sold, 1)
end)

test("vender: quantidades inválidas, favoritos e itens raros sem confirmação são recusados", function()
	local p = fresh()
	p.inventory.ball = 3
	p.inventory.teddy = 1
	for _, bad in ipairs({ 0, -1, 1.5, 4, 0 / 0 }) do
		truthy(not ProfileOps.sell(p, "ball", bad, false, NOW).ok, "quantidade " .. tostring(bad))
	end
	eq(ProfileOps.sell(p, "ball", "1", false, NOW).error, "amount")
	eq(p.inventory.ball, 3)
	ProfileOps.setFavorite(p, "ball", true)
	eq(ProfileOps.sell(p, "ball", 1, false, NOW).error, "favorite")
	local r = ProfileOps.sell(p, "teddy", 1, false, NOW)
	eq(r.error, "confirm")
	eq(r.needsConfirm, true)
	eq(p.inventory.teddy, 1)
	truthy(ProfileOps.sell(p, "teddy", 1, true, NOW).ok)
	eq(p.coins, 250 + 70)
end)

test("vender repetidos: mantém 1 de cada, ignora raros, favoritos e expostos", function()
	local p = fresh()
	p.inventory = { cup = 4, ball = 2, toy_car = 3, teddy = 5, watch = 3 }
	ProfileOps.setFavorite(p, "watch", true)
	truthy(ProfileOps.display(p, "toy_car", 1, NOW).ok)
	truthy(ProfileOps.display(p, "toy_car", 2, NOW).ok)
	local r = ProfileOps.sellDuplicates(p, NOW)
	truthy(r.ok, r.message)
	eq(p.inventory.cup, 1)
	eq(p.inventory.ball, 1)
	eq(p.inventory.toy_car, 2, "duas expostas ficam")
	eq(p.inventory.teddy, 5, "raro não é vendido")
	eq(p.inventory.watch, 3, "favorito protegido")
	eq(r.coins, 3 * 10 + 1 * 14 + 1 * 30)
	eq(ProfileOps.sellDuplicates(p, NOW).error, "none")
end)

test("vitrine: não expõe mais cópias do que possui e itens expostos não podem ser vendidos", function()
	local p = fresh()
	p.inventory.teddy = 1
	truthy(ProfileOps.display(p, "teddy", nil, NOW).ok)
	eq(p.showcase[1], "teddy")
	eq(ProfileOps.display(p, "teddy", 2, NOW).error, "noCopy")
	eq(ProfileOps.sell(p, "teddy", 1, true, NOW).error, "displayed")
	eq(ProfileOps.display(p, "cup", 1, NOW).error, "missing")
	p.inventory.cup = 1
	eq(ProfileOps.display(p, "cup", 3, NOW).error, "slot", "3º espaço exige melhoria")
	truthy(ProfileOps.display(p, "cup", 2, NOW).ok)
	eq(ProfileOps.display(p, "ball", nil, NOW).error, "missing")
	p.inventory.ball = 1
	eq(ProfileOps.display(p, "ball", nil, NOW).error, "full")
	-- trocar o objeto de um espaço libera o anterior
	truthy(ProfileOps.display(p, "ball", 1, NOW).ok)
	truthy(ProfileOps.sell(p, "teddy", 1, true, NOW).ok)
	truthy(ProfileOps.undisplay(p, 2).ok)
	eq(ProfileOps.undisplay(p, 2).error, "empty")
	eq(ProfileOps.undisplay(p, 99).error, "slot")
end)

test("melhorias: preço, efeito e nível máximo", function()
	local p = fresh()
	p.coins = 1000000
	eq(ProfileOps.capacity(p), 40)
	truthy(ProfileOps.buyUpgrade(p, "capacity").ok)
	eq(ProfileOps.capacity(p), 60)
	eq(p.coins, 1000000 - 200)
	for _ = 1, 10 do
		ProfileOps.buyUpgrade(p, "speed")
	end
	eq(p.upgrades.speed, UpgradeConfig.max("speed"))
	eq(ProfileOps.buyUpgrade(p, "speed").error, "max")
	eq(UpgradeConfig.openDuration(p.upgrades.speed), 1.8)
	truthy(ProfileOps.buyUpgrade(p, "showcase").ok)
	eq(ProfileOps.showcaseSlots(p), 3)
	truthy(ProfileOps.buyUpgrade(p, "missionBonus").ok)
	eq(ProfileOps.rewardCoins(p, 100), 110)
	eq(ProfileOps.buyUpgrade(p, "luck").error, "unknown")
	local poor = fresh()
	poor.coins = 10
	eq(ProfileOps.buyUpgrade(poor, "capacity").error, "coins")
	eq(poor.upgrades.capacity, 0)
end)

test("missões diárias: 3 por dia com 1 gratuita, progresso, resgate único e troca no dia seguinte", function()
	local p = fresh()
	local freeIds = {}
	for _, d in ipairs(MissionDefinitions.DailyFree) do
		freeIds[d.id] = true
	end
	truthy(freeIds[p.daily.missions[1].id], "primeira missão é gratuita")
	p.daily.missions[2] = { id = "d_open3", progress = 0, claimed = false }
	eq(ProfileOps.claimDaily(p, "d_open3", NOW).error, "incomplete")
	p.coins = 1000
	for _ = 1, 3 do
		ProfileOps.useMachine(p, "common", 0.1, NOW)
	end
	local coins = p.coins
	local r = ProfileOps.claimDaily(p, "d_open3", NOW)
	truthy(r.ok, r.message)
	eq(p.coins, coins + r.coins + (r.levelCoins or 0))
	eq(ProfileOps.claimDaily(p, "d_open3", NOW).error, "claimed")
	ProfileOps.ensureDaily(p, NOW + DAY)
	eq(p.daily.day, 20001)
	for _, m in ipairs(p.daily.missions) do
		eq(m.claimed, false)
		eq(m.progress, 0)
	end
end)

test("missão 'descobrir objeto' não aparece para quem já descobriu tudo", function()
	local p = fresh()
	for _, item in ipairs(ItemDefinitions.List) do
		p.discovered[item.id] = 1
	end
	for day = 20000, 20060 do
		for _, id in ipairs(ProfileOps.dailySelection(p, day)) do
			truthy(id ~= "d_discover", "dia " .. day)
		end
	end
end)

test("conquistas: só com a meta alcançada e uma única vez", function()
	local p = fresh()
	eq(ProfileOps.claimAchievement(p, "a_first").error, "incomplete")
	ProfileOps.useMachine(p, "common", 0.1, NOW)
	local r = ProfileOps.claimAchievement(p, "a_first")
	truthy(r.ok)
	eq(ProfileOps.claimAchievement(p, "a_first").error, "claimed")
	eq(ProfileOps.claimAchievement(p, "zzz").error, "unknown")
	p.stats.bestRank = 6
	truthy(ProfileOps.claimAchievement(p, "a_secret").ok)
	truthy(p.titles.secret_hunter)
end)

test("coleção: parte completa dá recompensa e título uma única vez; título só se desbloqueado", function()
	local p = fresh()
	eq(ProfileOps.setTitle(p, "starter").error, "locked")
	eq(ProfileOps.claimSet(p, "set_common").error, "incomplete")
	for _, id in ipairs({ "cup", "ball", "toy_car", "teddy", "headphones" }) do
		p.discovered[id] = NOW
	end
	eq(ProfileOps.metric(p, "setsComplete"), 1)
	local r = ProfileOps.claimSet(p, "set_common")
	truthy(r.ok)
	eq(r.title, "starter")
	eq(ProfileOps.claimSet(p, "set_common").error, "claimed")
	truthy(ProfileOps.setTitle(p, "starter").ok)
	eq(p.title, "starter")
	truthy(ProfileOps.setTitle(p, "").ok)
	eq(ProfileOps.claimSet(p, "set_all").error, "incomplete")
end)

test("presente diário: uma vez por dia, sequência continua e recomeça se pular um dia", function()
	local p = fresh()
	local r = ProfileOps.claimGift(p, NOW)
	truthy(r.ok)
	eq(r.streak, 1)
	eq(ProfileOps.claimGift(p, NOW + 60).error, "claimed")
	eq(ProfileOps.claimGift(p, NOW + DAY).streak, 2)
	eq(ProfileOps.claimGift(p, NOW + 2 * DAY).streak, 3)
	eq(ProfileOps.claimGift(p, NOW + 4 * DAY).streak, 1, "pulou um dia")
end)

test("moedas perdidas: limite por hora que renova na hora seguinte", function()
	local p = fresh()
	for _ = 1, EconomyConfig.Pickups.hourlyLimit do
		truthy(ProfileOps.pickup(p, NOW).ok)
	end
	eq(ProfileOps.pickup(p, NOW).error, "limit")
	truthy(ProfileOps.pickup(p, NOW + 3600).ok)
end)

test("jogador sem saldo e sem objetos consegue voltar a jogar com atividades gratuitas", function()
	local p = fresh()
	p.coins = 0
	truthy(not ProfileOps.useMachine(p, "common", 0.5, NOW).ok)
	ProfileOps.claimGift(p, NOW)
	for _ = 1, 3 do
		ProfileOps.pickup(p, NOW)
	end
	truthy(p.coins >= MachineDefinitions.cheapestPrice(), "coins " .. p.coins)
	truthy(ProfileOps.useMachine(p, "common", 0.5, NOW).ok)
end)

test("configurações: só chaves conhecidas e do tipo certo", function()
	local p = fresh()
	truthy(ProfileOps.setSetting(p, "autoSkip", true).ok)
	eq(p.settings.autoSkip, true)
	eq(ProfileOps.setSetting(p, "autoSkip", "sim").error, "invalid")
	eq(ProfileOps.setSetting(p, "coins", 5).error, "invalid")
end)

test("reparo de perfil corrompido", function()
	local bad = {
		coins = -50,
		xp = "abc",
		inventory = { cup = "3", fake_item = 9, ball = -2, teddy = 1.7 },
		favorites = { cup = true, fake = true },
		discovered = { nope = 1 },
		showcase = { "teddy", "teddy", "drone", 5 },
		upgrades = { capacity = 99, speed = -3, hack = 1 },
		stats = "x",
		daily = { day = 5, missions = { { id = "fake" } } },
		titles = { legend = true, fake = true },
		title = "fake",
		settings = { sound = "yes", extra = 1 },
	}
	local p, fixes = ProfileSchema.reconcile(bad)
	truthy(#fixes > 0)
	eq(p.coins, 0)
	eq(p.xp, 0)
	eq(p.inventory.cup, 3)
	eq(p.inventory.fake_item, nil)
	eq(p.inventory.ball, nil)
	eq(p.inventory.teddy, 1)
	truthy(p.discovered.cup and p.discovered.teddy, "possuídos contam como descobertos")
	eq(p.discovered.nope, nil)
	eq(p.showcase[1], "teddy")
	eq(p.showcase[2], "", "só 1 urso possuído")
	eq(p.showcase[3], "")
	eq(#p.showcase, UpgradeConfig.MaxShowcaseSlots)
	eq(p.upgrades.capacity, UpgradeConfig.max("capacity"))
	eq(p.upgrades.speed, 0)
	eq(p.upgrades.hack, nil)
	eq(p.stats.opens, 0)
	eq(p.daily.day, -1)
	eq(p.titles.fake, nil)
	eq(p.title, "")
	eq(p.settings.sound, true)
	eq(p.settings.extra, nil)
	local p2 = ProfileSchema.reconcile("lixo")
	eq(p2.coins, 250)
end)

test("fotografia do cliente traz HUD, missões, coleção e presentes calculados", function()
	local p = fresh()
	ProfileOps.useMachine(p, "common", 0.1, NOW)
	local v = ClientView.build(p, NOW)
	eq(v.coins, 225)
	eq(v.level, 1)
	eq(v.discoveredCount, 1)
	eq(v.totalItems, 20)
	eq(#v.daily, 3)
	eq(#v.achievements, #MissionDefinitions.Achievements)
	eq(#v.sets, #MissionDefinitions.CollectionSets)
	eq(find(v.sets, "set_common").have, 1)
	eq(v.gift.canClaim, true)
	eq(v.capacity, 40)
	eq(v.openDuration, UpgradeConfig.openDuration(0))
end)

test("formatação de números e porcentagens", function()
	eq(Format.int(1234567), "1.234.567")
	eq(Format.int(25), "25")
	eq(Format.short(1500), "1.500")
	eq(Format.short(25000), "25 mil")
	eq(Format.short(2500000), "2,5 mi")
	eq(Format.percent(45), "45%")
	eq(Format.percent(0.5), "0,5%")
	eq(Format.percent(7.5), "7,5%")
end)

print(string.format("\n%d passaram, %d falharam", passed, failed))
return failed == 0
