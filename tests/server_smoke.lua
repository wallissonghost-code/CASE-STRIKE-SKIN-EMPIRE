-- Teste de fumaça do SERVIDOR e do CLIENTE reais (src/) num ambiente Roblox simulado.
-- Cobre: carga/gravação com trava de sessão, distribuição das bases, esteira, ovos,
-- coleta dentro da base, escudo, roubo completo (pegar, defender, tempo esgotado, saídas),
-- remotes com deduplicação e limite de frequência, falhas de DataStore, reinício do servidor,
-- servidor cheio e a interface real conectada ao servidor.

local M = __mock

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
local function count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

---------------------------------------------------------------------------
-- carregamento dos scripts reais na árvore simulada
---------------------------------------------------------------------------
local moduleCache = {}
function require(inst)
	if moduleCache[inst] ~= nil then
		return moduleCache[inst]
	end
	local path = inst:GetAttribute("__path")
	assert(path, "require de instância sem arquivo: " .. tostring(inst.Name))
	local env = setmetatable({ script = inst }, { __index = _G })
	local chunk = assert(load(__readfile(path), "@" .. path, "t", env))
	local result = chunk()
	moduleCache[inst] = result
	return result
end
warn = function(...)
	local parts = {}
	for i, v in ipairs({ ... }) do
		parts[i] = tostring(v)
	end
	M.warnings = M.warnings or {}
	table.insert(M.warnings, table.concat(parts, " "))
end

local function mount(parent, folderName, diskPath)
	local folder = M.instance("Folder", folderName)
	folder.Parent = parent
	for _, entry in ipairs(__listdir(diskPath)) do
		local name, isDir = entry[1], entry[2]
		if isDir then
			mount(folder, name, diskPath .. "/" .. name)
		elseif string.sub(name, -4) == ".lua" then
			local base = string.gsub(name, "%.server%.lua$", "")
			base = string.gsub(base, "%.client%.lua$", "")
			base = string.gsub(base, "%.lua$", "")
			local class = "ModuleScript"
			if string.find(name, "%.server%.lua$") then
				class = "Script"
			elseif string.find(name, "%.client%.lua$") then
				class = "LocalScript"
			end
			local m = M.instance(class, base)
			m:SetAttribute("__path", diskPath .. "/" .. name)
			m.Parent = folder
		end
	end
	return folder
end

local function bootServer(jobId)
	moduleCache = {}
	M.fired = {}
	local g, RS = M.newGame(jobId)
	local shared = mount(RS, "Shared", "src/shared")
	local server = mount(g:GetService("ServerScriptService"), "Server", "src/server")
	M.run(function()
		require(server:FindFirstChild("Main"))
	end)
	local svc = function(name)
		return moduleCache[server.Services:FindFirstChild(name)]
	end
	return {
		remote = function(name)
			return RS:FindFirstChild("Remotes"):FindFirstChild(name)
		end,
		pds = svc("PlayerDataService"),
		base = svc("BaseService"),
		conveyor = svc("ConveyorService"),
		steal = svc("StealService"),
		events = svc("EventService"),
		map = svc("MapService"),
		eventConfig = moduleCache[shared.Config.EventConfig],
	}
end

local function invoke(server, name, player, payload)
	local rf = server.remote(name)
	return M.run(function()
		return rf.OnServerInvoke(player, payload)
	end)
end

local function lastView(player)
	for i = #M.fired, 1, -1 do
		local f = M.fired[i]
		if f.remote == "DataUpdated" and f.player == player then
			return f.data
		end
	end
end

local function notes(player, kind)
	local out = {}
	for _, f in ipairs(M.fired) do
		if f.remote == "Notify" and (f.player == player or f.all) and (not kind or f.data.kind == kind) then
			table.insert(out, f.data.text)
		end
	end
	return out
end

local function makeChar(p, x, z)
	local char = M.instance("Model", p.Name)
	local hrp = M.instance("Part", "HumanoidRootPart")
	hrp.Position = Vector3.new(x or 0, 3, z or 0)
	hrp.Parent = char
	local hum = M.instance("Humanoid", "Humanoid")
	hum.Parent = char
	p.Character = char
	char.Parent = workspace
	return char
end

local function moveTo(p, x, z)
	p.Character.HumanoidRootPart.Position = Vector3.new(x, 3, z)
end

local function join(S, id, name)
	local p = M.newPlayer(id, name)
	makeChar(p, 0, 30)
	M.addPlayer(p)
	M.advance(1)
	return p
end

local function triggerPrompt(prompt, player)
	game:GetService("ProximityPromptService").PromptTriggered:Fire(prompt, player)
	M.advance(0.05)
end

local function findPrompt(container, attr, value)
	for _, d in ipairs(container:GetDescendants()) do
		if d.ClassName == nil and rawget(d, "__class") == "ProximityPrompt" and d:GetAttribute(attr) == value then
			return d
		end
	end
end

local STORE = "MutantFactory_Profiles_v1"

---------------------------------------------------------------------------
print("== Servidor simulado ==")

local S = bootServer("job-A")
-- horário fixo fora de eventos para resultados previsíveis
local EC = S.eventConfig
M.epoch = math.floor((M.epoch) / EC.Period) * EC.Period + 600 - M.clock
local alice = join(S, 101, "Alice")
local MapConfig = moduleCache[game:GetService("ReplicatedStorage").Shared.Config.MapConfig]

test("servidor inicia, cria remotes, mapa e 6 bases", function()
	truthy(S.remote("EggAction") and S.remote("Notify"))
	local world = workspace:FindFirstChild("MutantWorld")
	truthy(world, "mapa construído")
	for i = 1, 6 do
		truthy(world:FindFirstChild("Base" .. i), "base " .. i)
	end
	truthy(world:FindFirstChild("ConveyorBelt"))
end)

test("perfil carrega com trava de sessão, base atribuída e personagem levado até ela", function()
	truthy(S.pds.isLoaded(alice))
	local rec = M.datastore[STORE]["p_101"]
	truthy(rec and rec.lock and rec.lock.jobId == "job-A", "trava gravada")
	eq(alice:GetAttribute("BaseIndex"), 1)
	local pos = alice.Character.HumanoidRootPart.Position
	eq(MapConfig.baseAt(pos.X, pos.Z), 1, "teleportado para a base")
	local v = lastView(alice)
	truthy(v, "DataUpdated enviado")
	eq(v.coins, 300)
	eq(v.baseIndex, 1)
	truthy(v.shieldUntil > 0, "proteção de novato")
	truthy(alice:FindFirstChild("leaderstats"))
end)

test("esteira solta criaturas e elas andam até sumir", function()
	M.advance(8)
	local n = count(S.conveyor._items)
	truthy(n >= 2, "itens na esteira: " .. n)
	local first
	for _, it in pairs(S.conveyor._items) do
		first = it
	end
	local x0 = first.x
	M.advance(2)
	truthy(first.x > x0, "andou")
end)

test("comprar na esteira: precisa estar perto, cobra o preço do servidor e vai para a base", function()
	local profile = S.pds.getProfile(alice)
	profile.coins = 1e7
	local id, item
	for k, it in pairs(S.conveyor._items) do
		id, item = k, it
	end
	local far = S.conveyor.buy(alice, id)
	eq(far.error, "too_far")
	moveTo(alice, item.x, 6)
	local price = item.offer.price
	local res = S.conveyor.buy(alice, id)
	truthy(res.ok, tostring(res.message))
	eq(profile.coins, 1e7 - price)
	eq(count(profile.creatures), 1)
	eq(S.conveyor._items[id], nil, "saiu da esteira")
	local again = S.conveyor.buy(alice, id)
	eq(again.error, "offer_gone")
	truthy(workspace.MutantWorld.Creatures:FindFirstChild("c1"), "modelo no pedestal")
end)

test("compra pela tecla E (prompt) na esteira", function()
	local id, item
	for k, it in pairs(S.conveyor._items) do
		id, item = k, it
	end
	moveTo(alice, item.x, 5)
	local before = count(S.pds.getProfile(alice).creatures)
	local prompt = findPrompt(item.model, "ConveyorId", id)
	truthy(prompt, "prompt existe")
	triggerPrompt(prompt, alice)
	eq(count(S.pds.getProfile(alice).creatures), before + 1)
end)

test("ovo via remote; pedido repetido não cobra duas vezes; formato inválido rejeitado", function()
	local profile = S.pds.getProfile(alice)
	local coins = profile.coins
	local res = invoke(S, "EggAction", alice, { action = "hatch", eggId = "raro", requestId = "egg-1" })
	truthy(res.ok, tostring(res.message))
	truthy(res.data.speciesId)
	eq(profile.coins, coins - 10000)
	local again = invoke(S, "EggAction", alice, { action = "hatch", eggId = "raro", requestId = "egg-1" })
	truthy(again.ok)
	eq(profile.coins, coins - 10000, "não cobrou de novo")
	for _, payload in ipairs({ "lixo", { action = 5 }, { action = "hatch", eggId = "../x" }, { action = "hatch", eggId = "basico", price = -1 } }) do
		M.advance(1)
		local r = invoke(S, "EggAction", alice, payload)
		if type(payload) == "table" and payload.price then
			truthy(r.ok, "preço do cliente ignorado")
			coins = coins - 300
		else
			eq(r.ok, false)
		end
	end
	eq(profile.coins, coins - 10000)
end)

test("limite de frequência dos ovos", function()
	M.advance(5)
	local limited = false
	for _ = 1, 8 do
		local r = invoke(S, "EggAction", alice, { action = "hatch", eggId = "basico" })
		if r.error == "rate_limited" then
			limited = true
		end
	end
	truthy(limited)
end)

test("coletar só dentro da própria base", function()
	M.advance(30)
	moveTo(alice, 0, 0)
	local out = invoke(S, "BaseAction", alice, { action = "collect" })
	eq(out.error, "not_in_base")
	local x, z = MapConfig.toWorld(1, 0, 20)
	moveTo(alice, x, z)
	local coins = S.pds.getProfile(alice).coins
	local res = invoke(S, "BaseAction", alice, { action = "collect" })
	truthy(res.ok, tostring(res.message))
	truthy(res.data.coins > 0)
	eq(S.pds.getProfile(alice).coins, coins + res.data.coins)
end)

local bob = join(S, 202, "Bob")
local function aliceUid()
	local best
	for uid, c in pairs(S.pds.getProfile(alice).creatures) do
		if not best or c.pad < S.pds.getProfile(alice).creatures[best].pad then
			best = uid
		end
	end
	return best
end
local function bobIntoAliceBase(uid)
	local c = S.pds.getProfile(alice).creatures[uid]
	local px, pz = MapConfig.padPosition(1, c.pad)
	moveTo(bob, px + 2, pz)
end
local function bobHome()
	local x, z = MapConfig.toWorld(2, 0, 20)
	moveTo(bob, x, z)
end

test("segundo jogador recebe outra base", function()
	eq(bob:GetAttribute("BaseIndex"), 2)
end)

test("proteção de novato impede roubo", function()
	local uid = aliceUid()
	bobIntoAliceBase(uid)
	local res = S.steal.begin(bob, alice, uid)
	eq(res.error, "shielded")
end)

test("roubo completo: pegar, dono avisado, venda travada, entrega muda o dono e salva os dois", function()
	M.advance(125) -- termina a proteção de novato
	local uid = aliceUid()
	local c = S.pds.getProfile(alice).creatures[uid]
	local species = c.s
	local aliceCount = count(S.pds.getProfile(alice).creatures)
	bobIntoAliceBase(uid)
	local prompt = findPrompt(workspace.MutantWorld.Creatures, "Uid", uid)
	truthy(prompt, "prompt de roubo")
	triggerPrompt(prompt, bob)
	truthy(S.steal._carries[bob], "Bob está carregando")
	truthy(bob.Character:FindFirstChild("CarriedCreature"), "criatura na cabeça")
	truthy(#notes(alice, "theft") >= 1, "Alice avisada")
	local sell = invoke(S, "BaseAction", alice, { action = "sell", uid = uid, confirm = true })
	eq(sell.error, "being_stolen")
	M.advance(1)
	eq(bob.Character.Humanoid.WalkSpeed, 12, "mais devagar carregando")
	bobHome()
	M.advance(0.5)
	eq(S.steal._carries[bob], nil)
	eq(count(S.pds.getProfile(alice).creatures), aliceCount - 1)
	local got
	for _, bc in pairs(S.pds.getProfile(bob).creatures) do
		got = bc
	end
	eq(got.s, species)
	eq(got.origin, "stolen")
	eq(S.pds.getProfile(bob).stats.stolen, 1)
	M.advance(4)
	local recA = M.datastore[STORE]["p_101"].data
	local recB = M.datastore[STORE]["p_202"].data
	eq(count(recA.creatures), aliceCount - 1, "vítima salva")
	eq(count(recB.creatures), 1, "ladrão salvo")
end)

test("defesa: o dono encosta em quem rouba e a criatura volta", function()
	local uid = aliceUid()
	bobIntoAliceBase(uid)
	local res = S.steal.begin(bob, alice, uid)
	truthy(res.ok, tostring(res.message))
	local pos = bob.Character.HumanoidRootPart.Position
	moveTo(alice, pos.X + 2, pos.Z)
	M.advance(0.5)
	eq(S.steal._carries[bob], nil)
	truthy(S.pds.getProfile(alice).creatures[uid], "voltou para Alice")
	eq(S.pds.getProfile(alice).stats.defended, 1)
	eq(bob.Character:FindFirstChild("CarriedCreature"), nil)
end)

test("tempo esgotado devolve a criatura", function()
	local uid = aliceUid()
	local ax, az = MapConfig.toWorld(1, 0, 20)
	moveTo(alice, ax + 30, az) -- longe
	bobIntoAliceBase(uid)
	truthy(S.steal.begin(bob, alice, uid).ok)
	moveTo(bob, 0, 0) -- foge para a praça e fica parado
	M.advance(46)
	eq(S.steal._carries[bob], nil)
	truthy(S.pds.getProfile(alice).creatures[uid])
end)

test("escudo: só dentro da base, empurra intrusos e bloqueia roubo", function()
	local uid = aliceUid()
	bobIntoAliceBase(uid)
	moveTo(alice, 0, 0)
	eq(invoke(S, "BaseAction", alice, { action = "shield" }).error, "not_in_base")
	local x, z = MapConfig.toWorld(1, 0, 20)
	moveTo(alice, x, z)
	local res = invoke(S, "BaseAction", alice, { action = "shield" })
	truthy(res.ok, tostring(res.message))
	M.advance(0.5)
	local bp = bob.Character.HumanoidRootPart.Position
	truthy(MapConfig.baseAt(bp.X, bp.Z) ~= 1, "Bob foi empurrado para fora")
	bobIntoAliceBase(uid)
	eq(S.steal.begin(bob, alice, uid).error, "shielded")
	eq(invoke(S, "BaseAction", alice, { action = "shield" }).error, "shield_active")
	M.advance(65)
	M.advance(1)
end)

test("escudo ligado com o ladrão ainda dentro devolve a criatura", function()
	local uid = aliceUid()
	bobIntoAliceBase(uid)
	local ax, az = MapConfig.toWorld(1, 20, 20)
	moveTo(alice, ax, az)
	truthy(S.steal.begin(bob, alice, uid).ok)
	truthy(invoke(S, "BaseAction", alice, { action = "shield" }).ok)
	eq(S.steal._carries[bob], nil)
	truthy(S.pds.getProfile(alice).creatures[uid])
	M.advance(72)
end)

test("ladrão sai do servidor no meio do roubo: criatura volta", function()
	local cara = join(S, 303, "Cara")
	local uid = aliceUid()
	local c = S.pds.getProfile(alice).creatures[uid]
	local px, pz = MapConfig.padPosition(1, c.pad)
	moveTo(cara, px + 2, pz)
	moveTo(alice, 300, 300)
	truthy(S.steal.begin(cara, alice, uid).ok)
	M.removePlayer(cara)
	M.advance(1)
	eq(S.steal._carries[cara], nil)
	truthy(S.pds.getProfile(alice).creatures[uid])
	truthy(workspace.MutantWorld.Creatures:FindFirstChild(uid), "modelo de volta ao pedestal")
end)

test("melhorias, poções, venda e missões via remotes", function()
	local profile = S.pds.getProfile(alice)
	profile.coins = 1e8
	local slots = invoke(S, "BaseAction", alice, { action = "upgrade", upgradeId = "slots" })
	truthy(slots.ok, tostring(slots.message))
	M.advance(0.1)
	eq(lastView(alice).slots, 10)
	truthy(invoke(S, "EggAction", alice, { action = "buyPotion", potionId = "sorte" }).ok)
	truthy(invoke(S, "EggAction", alice, { action = "usePotion", potionId = "sorte" }).ok)
	M.advance(0.1)
	truthy(lastView(alice).luck > 0)
	local uid = aliceUid()
	local n = count(profile.creatures)
	local sold = invoke(S, "BaseAction", alice, { action = "sell", uid = uid, confirm = true })
	truthy(sold.ok, tostring(sold.message))
	eq(count(profile.creatures), n - 1)
	eq(invoke(S, "BaseAction", alice, { action = "upgrade", upgradeId = "nada" }).ok, false)
	local gift = invoke(S, "ClaimAction", alice, { action = "gift" })
	truthy(gift.ok, tostring(gift.message))
	eq(invoke(S, "ClaimAction", alice, { action = "gift" }).error, "already_claimed")
	local studioOnly = invoke(S, "SettingsAction", alice, { action = "testEvent", eventId = "hora_sorte" })
	eq(studioOnly.error, "forbidden", "evento de teste só no Studio")
	local set = invoke(S, "SettingsAction", alice, { action = "set", key = "reduceEffects", value = true })
	truthy(set.ok)
end)

test("evento começa: todos são avisados e a sorte da esteira/ovos muda", function()
	S.events.force("hora_sorte", 60)
	local found = false
	for _, t in ipairs(notes(alice, "event")) do
		if string.find(t, "Hora da Sorte", 1, true) then
			found = true
		end
	end
	truthy(found, "aviso do evento")
	M.advance(0.2)
	truthy(lastView(alice).event and lastView(alice).event.id == "hora_sorte")
	EC.override = nil
end)

test("renascimento via remote", function()
	local profile = S.pds.getProfile(alice)
	profile.coins = 1e7
	local wrong = invoke(S, "ClaimAction", alice, { action = "rebirth", phrase = "sim" })
	eq(wrong.error, "confirmation_required")
	local res = invoke(S, "ClaimAction", alice, { action = "rebirth", phrase = "RENASCER" })
	truthy(res.ok, tostring(res.message))
	profile = S.pds.getProfile(alice) -- o pedido recusado antes restaurou a cópia de segurança
	eq(profile.rebirths, 1)
	eq(count(profile.creatures), 0)
	for _, m in ipairs(workspace.MutantWorld.Creatures:GetChildren()) do
		truthy(m:GetAttribute("OwnerUserId") ~= 101, "modelo da Alice sobrou: " .. m.Name)
	end
end)

test("ranking do servidor", function()
	local r = invoke(S, "RankingRequest", bob, { action = "get" })
	truthy(r.ok)
	eq(#r.data, 2)
end)

test("servidor cheio: 7º jogador é avisado", function()
	local extra = {}
	for i = 1, 4 do
		extra[i] = join(S, 400 + i, "P" .. i)
	end
	local seventh = join(S, 499, "Sétimo")
	truthy(seventh.kicked and string.find(seventh.kicked, "cheio"), "expulso com aviso")
	for _, p in ipairs(extra) do
		M.removePlayer(p)
	end
	M.advance(2)
end)

test("falhas temporárias do DataStore são repetidas e o salvamento conclui", function()
	S.pds.getProfile(bob).coins = 4242
	M.failNext = 2
	M.advance(70) -- autosave
	eq(M.datastore[STORE]["p_202"].data.coins, 4242)
end)

local bobCoins = S.pds.getProfile(bob).coins
local bobCreatures = count(S.pds.getProfile(bob).creatures)

test("perfil travado por outro servidor não é carregado", function()
	M.datastore[STORE]["p_777"] = { data = { coins = 5 }, lock = { jobId = "job-X", time = M.epoch + M.clock } }
	local p = M.newPlayer(777, "Travado")
	makeChar(p, 0, 0)
	M.addPlayer(p)
	M.advance(40)
	truthy(p.kicked, "expulso com aviso")
	eq(M.datastore[STORE]["p_777"].data.coins, 5, "dados intactos")
end)

test("saída libera a trava e reinício do servidor mantém moedas e criaturas", function()
	M.removePlayer(bob)
	M.advance(2)
	local rec = M.datastore[STORE]["p_202"]
	eq(rec.lock, nil, "trava liberada")
	for _, f in ipairs(M.closeHandlers) do
		M.run(f)
	end
	local S2 = bootServer("job-B")
	local bob2 = join(S2, 202, "Bob")
	M.advance(2)
	local p = S2.pds.getProfile(bob2)
	truthy(p, "carregou")
	eq(p.coins, bobCoins)
	eq(count(p.creatures), bobCreatures)
	S = S2
	bob = bob2
end)

test("nenhum aviso inesperado no servidor", function()
	local unexpected = {}
	for _, w in ipairs(M.warnings or {}) do
		if not string.find(w, "UpdateAsync falhou") and not string.find(w, "travado por outro servidor") then
			table.insert(unexpected, w)
		end
	end
	eq(#unexpected, 0, table.concat(unexpected, " | "))
end)

---------------------------------------------------------------------------
print("== Cliente simulado (interface real conectada ao servidor) ==")

local Players = game:GetService("Players")
rawset(Players, "LocalPlayer", bob)
M.localPlayer = bob
S.pds.getProfile(bob).coins = 500000

local clientFolder = mount(M.instance("Folder", "StarterPlayerScripts"), "Client", "src/client")
local clientOk, clientErr = pcall(function()
	M.run(function()
		require(clientFolder:FindFirstChild("Main"))
	end)
end)
M.advance(3)
local UI = clientFolder.Controllers and moduleCache[clientFolder.Controllers:FindFirstChild("UIController")]
local Store = clientFolder.Util and moduleCache[clientFolder.Util:FindFirstChild("Store")]

local function screensInOrder()
	local first, last, middle = {}, {}, {}
	for _, g in ipairs(bob.PlayerGui:GetChildren()) do
		if g.Name == "Dialogs" or g.Name == "Hatch" then
			table.insert(first, g)
		elseif g.Name == "MainHUD" or g.Name == "Toasts" then
			table.insert(last, g)
		else
			table.insert(middle, g)
		end
	end
	local out = {}
	for _, list in ipairs({ first, middle, last }) do
		for _, g in ipairs(list) do
			table.insert(out, g)
		end
	end
	return out
end
local function findButton(text, plain)
	for _, screenGui in ipairs(screensInOrder()) do
		for _, d in ipairs(screenGui:GetDescendants()) do
			if d:IsA("TextButton") and d.Text and (d.Text == text or (plain and string.find(d.Text, text, 1, true))) then
				local visible = true
				local node = d
				while node do
					if node.Visible == false then
						visible = false
					end
					node = node.Parent
				end
				if visible then
					return d
				end
			end
		end
	end
	return nil
end
local function click(text, plain)
	local b = findButton(text, plain)
	assert(b, "botão não encontrado: " .. text)
	b.Activated:Fire()
	M.advance(0.6)
	return b
end

test("cliente inicia sem erros e recebe a fotografia", function()
	truthy(clientOk, tostring(clientErr))
	truthy(bob.PlayerGui:FindFirstChild("MainHUD"), "HUD")
	truthy(Store and Store.view, "fotografia recebida")
	eq(Store.view.coins, 500000)
end)

test("todos os painéis abrem sem erros", function()
	for _, name in ipairs({ "Eggs", "Base", "Index", "Missions", "Gifts", "Potions", "Rebirth", "Ranking", "Settings" }) do
		UI.open(name)
		M.advance(0.3)
		eq(UI.current, name)
	end
	UI.close(true)
end)

test("abrir ovo pela interface entrega uma criatura", function()
	local before = count(S.pds.getProfile(bob).creatures)
	UI.open("Eggs", { eggId = "basico" })
	M.advance(0.3)
	click("ABRIR", true)
	M.advance(4)
	eq(count(S.pds.getProfile(bob).creatures), before + 1)
	UI.close(true)
end)

test("base pela interface: melhorar e coletar", function()
	UI.open("Base")
	M.advance(0.3)
	local lvl = S.pds.getProfile(bob).upgrades.storage
	click("Cofre maior", true)
	eq(S.pds.getProfile(bob).upgrades.storage, lvl + 1)
	UI.close(true)
end)

test("presente diário pela interface", function()
	UI.open("Gifts")
	M.advance(0.3)
	click("RESGATAR", true)
	eq(S.pds.getProfile(bob).gifts.streak >= 1, true)
	UI.close(true)
end)

test("aviso de roubo aparece para a vítima", function()
	S.base.notify(bob, "theft", "🚨 Teste pegou seu Gosminha!")
	M.advance(0.5)
	local found = false
	for _, d in ipairs(bob.PlayerGui:GetDescendants()) do
		if d.Text and string.find(tostring(d.Text), "pegou seu Gosminha", 1, true) then
			found = true
		end
	end
	truthy(found)
end)

test("nenhum aviso inesperado no cliente", function()
	local unexpected = {}
	for _, w in ipairs(M.warnings or {}) do
		if not string.find(w, "UpdateAsync falhou") and not string.find(w, "travado por outro servidor") then
			table.insert(unexpected, w)
		end
	end
	eq(#unexpected, 0, table.concat(unexpected, " | "))
end)

print(string.format("\n%d passaram, %d falharam", passed, failed))
return failed == 0
