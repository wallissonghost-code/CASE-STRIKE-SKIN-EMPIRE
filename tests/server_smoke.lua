-- Teste do SERVIDOR e do CLIENTE reais (src/) num ambiente Roblox simulado (tests/roblox_mock.lua).
-- Cobre: mapa, carga/gravação com trava de sessão, máquinas (proximidade, preço do servidor,
-- requestId repetido, intervalo, nível), inventário, vitrine 3D, melhorias, presentes, moedas
-- perdidas, títulos, ranking, falhas de DataStore, reinício de servidor, modo memória e a
-- interface real conectada ao servidor (cliques nos botões).

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
local realPrint = print
print = function(...)
	local first = tostring((...))
	if string.sub(first, 1, 17) ~= "[MYSTERY MACHINE]" then
		realPrint(...)
	end
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

local STORE = "MysteryMachine_Profiles_v1"

local function bootServer(jobId, before)
	moduleCache = {}
	M.fired = {}
	local g, RS = M.newGame(jobId)
	if before then
		before()
	end
	local shared = mount(RS, "Shared", "src/shared")
	local server = mount(g:GetService("ServerScriptService"), "Server", "src/server")
	M.run(function()
		require(server:FindFirstChild("Main"))
	end)
	local function svc(name)
		return moduleCache[server.Services:FindFirstChild(name)]
	end
	return {
		remote = function(name)
			return RS:FindFirstChild("Remotes"):FindFirstChild(name)
		end,
		pds = svc("PlayerDataService"),
		map = svc("MapService"),
		machine = svc("MachineService"),
		economy = svc("EconomyService"),
		showcase = svc("ShowcaseService"),
		leaderboard = svc("LeaderboardService"),
		mission = svc("MissionService"),
		shared = function(path)
			local node = shared
			for part in string.gmatch(path, "[^/]+") do
				node = node:FindFirstChild(part)
			end
			return moduleCache[node] or require(node)
		end,
	}
end

local function invoke(server, name, player, payload)
	local rf = server.remote(name)
	return M.run(function()
		return rf.OnServerInvoke(player, payload)
	end)
end

local function makeChar(p, x, z)
	local char = M.instance("Model", p.Name)
	local hrp = M.instance("Part", "HumanoidRootPart")
	hrp.Position = Vector3.new(x or 0, 3, z or 0)
	hrp.Parent = char
	local head = M.instance("Part", "Head")
	head.Parent = char
	local hum = M.instance("Humanoid", "Humanoid")
	hum.Parent = char
	p.Character = char
	char.Parent = workspace
	return char
end

local function moveTo(p, pos)
	p.Character.HumanoidRootPart.Position = Vector3.new(pos.X, 3, pos.Z)
end

local function join(id, name)
	local p = M.newPlayer(id, name)
	makeChar(p, 0, 8)
	M.addPlayer(p)
	M.advance(1)
	return p
end

local function leave(p)
	M.removePlayer(p)
	M.advance(2)
end

local function record(userId)
	return M.datastore[STORE] and M.datastore[STORE]["Player_" .. userId]
end

local function firedTo(player, remote)
	local out = {}
	for _, f in ipairs(M.fired) do
		if f.remote == remote and (f.player == player or f.all) then
			table.insert(out, f.data)
		end
	end
	return out
end

local function notes(player)
	local out = {}
	for _, d in ipairs(firedTo(player, "Notify")) do
		table.insert(out, d.text)
	end
	return table.concat(out, " | ")
end

local function nearMachine(S, p, id)
	moveTo(p, S.map.machines[id].standPoint)
end

local function use(S, p, id, extra)
	local payload = { action = "use", machineId = id }
	for k, v in pairs(extra or {}) do
		payload[k] = v
	end
	local r = invoke(S, "RequestMachineUse", p, payload)
	M.advance(1)
	return r
end

---------------------------------------------------------------------------
print("== Servidor simulado ==")

local S = bootServer("job-A")
local alice = join(101, "Alice")

test("servidor inicia: remotes, parque, 4 máquinas físicas, loja, ranking e 8 vitrines", function()
	for _, name in ipairs({ "RequestMachineUse", "MachineResult", "InventoryAction", "UpgradeAction", "DataUpdated", "ProgressAction", "Notify" }) do
		truthy(S.remote(name), "remote " .. name)
	end
	local world = workspace:FindFirstChild("MysteryPark")
	truthy(world, "mapa")
	for _, id in ipairs({ "common", "neon", "golden", "mystery" }) do
		local model = world.Machines:FindFirstChild("Machine_" .. id)
		truthy(model, "máquina " .. id)
		for _, partName in ipairs({ "Body", "Visor", "Tray", "TrayPoint", "Button", "Lights", "Capsules", "Sign" }) do
			truthy(model:FindFirstChild(partName), id .. "." .. partName)
		end
		local prompt = model.Button:FindFirstChildOfClass("ProximityPrompt")
		truthy(prompt and prompt:GetAttribute("MachineId") == id, "botão com prompt")
	end
	truthy(world:FindFirstChild("UpgradeShop") and world:FindFirstChild("RankingBoard") and world:FindFirstChild("Gallery"))
	truthy(world:FindFirstChild("FutureArea"), "área para futuras atualizações")
	eq(#S.map.booths, 8)
	truthy(world:FindFirstChild("Spawn"))
end)

test("perfil novo: 250 Coins, trava de sessão gravada, leaderstats, vitrine e fotografia enviada", function()
	truthy(S.pds.isLoaded(alice))
	eq(S.pds.getProfile(alice).coins, 250)
	local rec = record(101)
	truthy(rec and rec.lock and rec.lock.job == "job-A", "trava")
	eq(alice.leaderstats.Coins.Value, 250)
	truthy(S.showcase.boothOf(alice), "estande atribuído")
	local views = firedTo(alice, "DataUpdated")
	truthy(#views > 0 and views[#views].coins == 250)
end)

test("máquina: longe recusa; perto cobra 25, entrega objeto e anima para todos", function()
	moveTo(alice, Vector3.new(0, 0, 40))
	local far = use(S, alice, "common")
	eq(far.error, "far")
	eq(S.pds.getProfile(alice).coins, 250)
	nearMachine(S, alice, "common")
	M.fired = {}
	local r = use(S, alice, "common")
	truthy(r.ok, r.message)
	local p = S.pds.getProfile(alice)
	eq(p.coins, 225)
	eq(p.inventory[r.itemId], 1)
	truthy(p.discovered[r.itemId])
	local broadcast = firedTo(nil, "MachineResult")
	eq(#broadcast, 1)
	eq(broadcast[1].itemId, r.itemId)
	eq(alice.leaderstats.Coins.Value, 225)
end)

test("máquina: preço/resultado enviados pelo cliente são ignorados", function()
	local before = S.pds.getProfile(alice).coins
	local r = use(S, alice, "common", { price = 0, itemId = "secret_artifact", r = 0.99999 })
	truthy(r.ok)
	eq(S.pds.getProfile(alice).coins, before - 25 + r.levelCoins)
end)

test("máquina: mesmo requestId repetido não cobra duas vezes", function()
	local before = S.pds.getProfile(alice).coins
	local r1 = use(S, alice, "common", { requestId = "abc-1" })
	local r2 = use(S, alice, "common", { requestId = "abc-1" })
	truthy(r1.ok)
	eq(r2.itemId, r1.itemId)
	eq(S.pds.getProfile(alice).coins, before - 25 + r1.levelCoins, "subida de nível incluída")
end)

test("máquina: aberturas simultâneas recusadas pelo intervalo mínimo e limite de frequência", function()
	M.advance(2)
	local first = invoke(S, "RequestMachineUse", alice, { action = "use", machineId = "common" })
	local second = invoke(S, "RequestMachineUse", alice, { action = "use", machineId = "common" })
	truthy(first.ok)
	eq(second.error, "busy")
	local errors = {}
	for _ = 1, 8 do
		local r = invoke(S, "RequestMachineUse", alice, { action = "use", machineId = "common" })
		errors[r.error or "ok"] = true
	end
	truthy(errors.rate, "limite de frequência")
	M.advance(3)
end)

test("máquina: bloqueada por nível e desconhecida", function()
	nearMachine(S, alice, "neon")
	eq(use(S, alice, "neon").error, "locked")
	eq(invoke(S, "RequestMachineUse", alice, { action = "use", machineId = { "x" } }).error, "unknown")
	eq(invoke(S, "RequestMachineUse", alice, "lixo").error, "invalid")
end)

test("inventário: vender atualiza saldo; vender a mesma cópia duas vezes falha", function()
	local p = S.pds.getProfile(alice)
	p.inventory = { cup = 1 }
	local coins = p.coins
	local r1 = invoke(S, "InventoryAction", alice, { action = "sell", itemId = "cup", amount = 1, value = 999999 })
	truthy(r1.ok, r1.message)
	eq(p.coins, coins + 10, "valor do servidor")
	local r2 = invoke(S, "InventoryAction", alice, { action = "sell", itemId = "cup", amount = 1 })
	eq(r2.error, "missing")
	eq(p.coins, coins + 10)
end)

test("vitrine: expor mostra o modelo 3D com placa no estande; item exposto não pode ser vendido", function()
	local p = S.pds.getProfile(alice)
	p.inventory.teddy = 1
	local r = invoke(S, "InventoryAction", alice, { action = "display", itemId = "teddy" })
	truthy(r.ok, r.message)
	M.advance(0.5)
	local booth = S.map.booths[S.showcase.boothOf(alice)]
	truthy(booth.slots[1].model, "modelo exposto")
	eq(booth.slots[1].model.Name, "teddy")
	truthy(string.find(booth.sign.Text, "Alice"), "placa do dono")
	eq(invoke(S, "InventoryAction", alice, { action = "sell", itemId = "teddy", amount = 1, confirm = true }).error, "displayed")
	eq(invoke(S, "InventoryAction", alice, { action = "display", itemId = "teddy", slot = 2 }).error, "noCopy")
	truthy(invoke(S, "InventoryAction", alice, { action = "undisplay", slot = 1 }).ok)
	M.advance(0.5)
	eq(booth.slots[1].model, nil)
end)

test("melhorias pelo remote", function()
	local p = S.pds.getProfile(alice)
	p.coins = 1000
	local r = invoke(S, "UpgradeAction", alice, { action = "buy", upgradeId = "capacity" })
	truthy(r.ok, r.message)
	eq(p.coins, 800)
	eq(p.upgrades.capacity, 1)
end)

test("presente diário pelo remote: uma vez por dia", function()
	local r = invoke(S, "ProgressAction", alice, { action = "claimGift" })
	truthy(r.ok, r.message)
	eq(invoke(S, "ProgressAction", alice, { action = "claimGift" }).error, "claimed")
end)

test("moedas perdidas: só coleta quem está perto, e a moeda reaparece", function()
	local coins = S.economy.activeCoins()
	local spot, coin = next(coins)
	truthy(coin, "moeda no mapa")
	local p = S.pds.getProfile(alice)
	local before = p.coins
	moveTo(alice, Vector3.new(coin.Position.X + 40, 0, coin.Position.Z))
	coin.Touched:Fire(alice.Character.HumanoidRootPart)
	M.advance(0.2)
	eq(p.coins, before, "longe não coleta")
	moveTo(alice, coin.Position)
	coin.Touched:Fire(alice.Character.HumanoidRootPart)
	M.advance(0.2)
	truthy(p.coins > before, "coletou")
	eq(coins[spot], nil)
	local count = 0
	for _ in pairs(coins) do
		count = count + 1
	end
	M.advance(25)
	local after = 0
	for _ in pairs(coins) do
		after = after + 1
	end
	eq(after, count + 1, "reapareceu")
end)

test("teleporte do menu leva até a máquina", function()
	local r = invoke(S, "ProgressAction", alice, { action = "goto", target = "golden" })
	truthy(r.ok)
	local pos = alice.Character.HumanoidRootPart.Position
	eq(pos.Z, S.map.machines.golden.standPoint.Z)
	eq(invoke(S, "ProgressAction", alice, { action = "goto", target = "lua" }).error, "invalid")
end)

test("coleção: completar parte dá título exibido acima da cabeça", function()
	local p = S.pds.getProfile(alice)
	for _, id in ipairs({ "cup", "ball", "toy_car", "teddy", "headphones" }) do
		p.discovered[id] = 1
	end
	truthy(invoke(S, "ProgressAction", alice, { action = "claimSet", setId = "set_common" }).ok)
	truthy(invoke(S, "ProgressAction", alice, { action = "setTitle", titleId = "starter" }).ok)
	M.advance(0.5)
	local tag = alice.Character.Head:FindFirstChild("TitleTag")
	truthy(tag, "título no personagem")
	truthy(string.find(notes(alice), "Novo título"), "aviso de título")
end)

test("missão de tempo de jogo avança sozinha", function()
	local p = S.pds.getProfile(alice)
	local playMission
	for _, m in ipairs(p.daily.missions) do
		if m.id == "d_play" or m.id == "d_pickup" then
			playMission = m
		end
	end
	truthy(playMission)
	local before = playMission.progress
	S.mission.tickPlaytime()
	if playMission.id == "d_play" then
		eq(playMission.progress, before + S.mission.PlaytimeTick)
	end
end)

test("erro inesperado no meio de uma operação restaura o perfil", function()
	local p = S.pds.getProfile(alice)
	local coins = p.coins
	local ProfileOps = S.shared("Logic/ProfileOps")
	local original = ProfileOps.buyUpgrade
	ProfileOps.buyUpgrade = function(profile)
		profile.coins = 0
		error("falha simulada")
	end
	local r = invoke(S, "UpgradeAction", alice, { action = "buy", upgradeId = "speed" })
	ProfileOps.buyUpgrade = original
	eq(r.error, "server")
	eq(S.pds.getProfile(alice).coins, coins)
end)

test("ranking: servidor calcula da memória e grava o global no OrderedDataStore", function()
	local bob = join(102, "Bob")
	S.pds.getProfile(bob).inventory = { crown = 1 }
	M.advance(20)
	local cache = S.leaderboard.get()
	eq(cache.server.value[1].name, "Bob")
	truthy(M.datastore["MysteryMachine_LB_value_v1"]["101"], "global gravado")
	leave(bob)
end)

test("autosave renova a trava e tenta de novo após falha temporária", function()
	M.failNext = 1
	M.advance(65)
	local rec = record(101)
	eq(rec.data.coins, S.pds.getProfile(alice).coins)
	truthy(rec.lock and rec.lock.job == "job-A")
	eq(M.failNext, 0)
end)

test("saída salva e libera a trava; outro servidor carrega os mesmos dados", function()
	local p = S.pds.getProfile(alice)
	p.coins = 4321
	p.inventory.diamond = 2
	leave(alice)
	local rec = record(101)
	eq(rec.lock, nil, "trava liberada")
	eq(rec.data.coins, 4321)
	local S2 = bootServer("job-B")
	local again = join(101, "Alice")
	local p2 = S2.pds.getProfile(again)
	truthy(p2, "carregou")
	eq(p2.coins, 4321)
	eq(p2.inventory.diamond, 2)
	S = S2
	alice = again
end)

test("trava de sessão: segundo servidor não carrega nem sobrescreve perfil aberto", function()
	local rec = record(101)
	local coins = rec.data.coins
	-- outro servidor tenta abrir o mesmo jogador
	local S3 = bootServer("job-C")
	local clone = M.newPlayer(101, "Alice")
	makeChar(clone, 0, 8)
	M.addPlayer(clone)
	M.advance(40)
	eq(S3.pds.isLoaded(clone), false)
	truthy(clone.kicked and string.find(clone.kicked, "outro servidor"), "aviso")
	eq(record(101).lock.job, "job-B")
	eq(record(101).data.coins, coins)
end)

test("falha ao carregar: jogador é avisado e nada é gravado por cima", function()
	M.datastore[STORE]["Player_303"] = { data = { coins = 999, inventory = { crown = 1 } } }
	local S4 = bootServer("job-D")
	M.failNext = 50
	local carol = M.newPlayer(303, "Carol")
	makeChar(carol, 0, 8)
	M.addPlayer(carol)
	M.advance(60)
	M.failNext = 0
	eq(S4.pds.isLoaded(carol), false)
	truthy(carol.kicked, "desconectado com aviso")
	eq(record(303).data.coins, 999)
	eq(record(303).data.inventory.crown, 1)
end)

test("perfil corrompido é reparado ao carregar", function()
	M.datastore[STORE]["Player_404"] = { data = { coins = -10, inventory = { cup = "2", hack = 50 }, showcase = { "hack" } } }
	local S5 = bootServer("job-E")
	local dan = join(404, "Dan")
	local p = S5.pds.getProfile(dan)
	eq(p.coins, 0)
	eq(p.inventory.cup, 2)
	eq(p.inventory.hack, nil)
	eq(p.showcase[1], "")
	leave(dan)
end)

test("desligamento do servidor salva todos e libera as travas", function()
	local S6 = bootServer("job-F")
	local eve = join(505, "Eve")
	S6.pds.getProfile(eve).coins = 777
	M.run(function()
		for _, fn in ipairs(M.closeHandlers) do
			fn()
		end
	end)
	eq(record(505).data.coins, 777)
	eq(record(505).lock, nil)
end)

test("pedido de quem saiu é recusado", function()
	local S7 = bootServer("job-G")
	local fay = join(606, "Fay")
	leave(fay)
	eq(invoke(S7, "RequestMachineUse", fay, { action = "use", machineId = "common" }).error, "loading")
end)

test("sem acesso a API (Studio): modo memória avisa e o jogo funciona", function()
	local S8 = bootServer("job-H", function()
		M.services.DataStoreService = {
			GetDataStore = function()
				return {
					UpdateAsync = function()
						error("403: You must publish this place to access DataStore (Studio API access)")
					end,
				}
			end,
			GetOrderedDataStore = function()
				return {}
			end,
		}
	end)
	eq(S8.pds.memoryMode, true)
	local gus = join(707, "Gus")
	truthy(S8.pds.isLoaded(gus))
	eq(S8.pds.getProfile(gus).coins, 250)
	local found = false
	for _, w in ipairs(M.warnings or {}) do
		if string.find(w, "MODO MEMÓRIA") then
			found = true
		end
	end
	truthy(found, "aviso de modo memória")
end)

---------------------------------------------------------------------------
print("== Cliente simulado (interface real conectada ao servidor) ==")

S = bootServer("job-UI")
local hero = join(808, "Hero")
local Players = game:GetService("Players")
rawset(Players, "LocalPlayer", hero)
M.localPlayer = hero
nearMachine(S, hero, "common")

local clientFolder = mount(M.instance("Folder", "StarterPlayerScripts"), "Client", "src/client")
local clientOk, clientErr = pcall(function()
	M.run(function()
		require(clientFolder:FindFirstChild("Main"))
	end)
end)
M.advance(3)
local UI = moduleCache[clientFolder.Controllers:FindFirstChild("UIController")]
local Store = moduleCache[clientFolder.Util:FindFirstChild("Store")]

local function visible(node)
	while node do
		if node.Visible == false then
			return false
		end
		node = node.Parent
	end
	return true
end

local ORDER = { Dialogs = 1, MainHUD = 3, Toasts = 3 }
local function findButton(text, plain)
	local screens = hero.PlayerGui:GetChildren()
	table.sort(screens, function(a, b)
		return (ORDER[a.Name] or 2) < (ORDER[b.Name] or 2)
	end)
	for _, gui in ipairs(screens) do
		for _, d in ipairs(gui:GetDescendants()) do
			if d:IsA("TextButton") and d.Text and (d.Text == text or (plain and string.find(d.Text, text, 1, true))) and visible(d) then
				return d
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
local function screenText(text)
	for _, d in ipairs(hero.PlayerGui:GetDescendants()) do
		if d.Text and string.find(tostring(d.Text), text, 1, true) and visible(d) then
			return true
		end
	end
	return false
end

test("cliente inicia sem erros, monta o HUD e recebe a fotografia", function()
	truthy(clientOk, tostring(clientErr))
	local hud = hero.PlayerGui:FindFirstChild("MainHUD")
	truthy(hud, "MainHUD")
	truthy(Store.view, "fotografia")
	eq(Store.view.coins, 250)
	truthy(screenText("💰 250"), "Coins no HUD")
	truthy(screenText("Nv 1"), "nível no HUD")
end)

test("todos os painéis do menu lateral abrem, um por vez, nas telas pedidas", function()
	local screens = { Machines = "MachineUI", Inventory = "InventoryUI", Collection = "CollectionUI", Upgrades = "UpgradeUI", Missions = "MissionUI", Ranking = "RankingUI", Settings = "SettingsUI" }
	for panel, screen in pairs(screens) do
		hero.PlayerGui.MainHUD.SideMenu:FindFirstChild(panel).Activated:Fire()
		M.advance(0.6)
		eq(UI.current, panel)
		truthy(hero.PlayerGui:FindFirstChild(screen), "tela " .. screen)
		local open = 0
		for _, p in pairs(UI.panels) do
			if p.window and p.window.Visible then
				open = open + 1
			end
		end
		eq(open, 1, "só uma janela aberta")
	end
	UI.close(true)
end)

test("prompt da máquina abre o painel com as chances reais", function()
	local prompt = S.map.machines.common.button:FindFirstChildOfClass("ProximityPrompt")
	game:GetService("ProximityPromptService").PromptTriggered:Fire(prompt, hero)
	M.advance(0.5)
	eq(UI.current, "Machine")
	truthy(screenText("Chances reais"), "título das chances")
	truthy(screenText("45%") and screenText("2%"), "porcentagens")
	truthy(findButton("USAR MÁQUINA", true), "botão usar")
end)

test("USAR MÁQUINA: cobra no servidor, anima, permite pular e mostra o resultado", function()
	local before = S.pds.getProfile(hero).coins
	click("USAR MÁQUINA", true)
	local MC = moduleCache[clientFolder.Controllers:FindFirstChild("MachineController")]
	eq(S.pds.getProfile(hero).coins, before - 25 + MC.state().result.levelCoins)
	truthy(findButton("PULAR", true), "botão pular durante a animação")
	click("PULAR", true)
	local MachineController = moduleCache[clientFolder.Controllers:FindFirstChild("MachineController")]
	eq(MachineController.state().phase, "result")
	local itemId = MachineController.state().result.itemId
	eq(S.pds.getProfile(hero).inventory[itemId], 1)
	M.advance(1)
	truthy(S.map.machines.common.model:FindFirstChild("Prize"), "objeto no compartimento")
	truthy(findButton("VENDER", true), "ações do resultado")
end)

test("vender o prêmio pela tela de resultado", function()
	local MachineController = moduleCache[clientFolder.Controllers:FindFirstChild("MachineController")]
	local itemId = MachineController.state().result.itemId
	local p = S.pds.getProfile(hero)
	local coins = p.coins
	click("VENDER", true)
	local confirm = findButton("Vender")
	if confirm then
		confirm.Activated:Fire()
		M.advance(0.6)
	end
	eq(p.inventory[itemId], nil)
	truthy(p.coins > coins)
	UI.close(true)
end)

test("animação sem pular termina sozinha", function()
	UI.open("Machine", { machineId = "common" })
	M.advance(0.3)
	M.advance(3)
	click("USAR MÁQUINA", true)
	M.advance(6)
	local MachineController = moduleCache[clientFolder.Controllers:FindFirstChild("MachineController")]
	eq(MachineController.state().phase, "result")
	UI.close(true)
end)

test("inventário: cartão, favoritar protege da venda, vender pelo painel", function()
	local p = S.pds.getProfile(hero)
	p.inventory = { ball = 3 }
	S.pds.markDirty(hero)
	M.advance(0.5)
	UI.open("Inventory")
	M.advance(0.3)
	truthy(screenText("Bola"), "cartão")
	truthy(screenText("x3"), "quantidade")
	local card
	for _, d in ipairs(hero.PlayerGui.InventoryUI:GetDescendants()) do
		if d.Name == "Card1" then
			card = d
		end
	end
	card.Activated:Fire()
	M.advance(0.3)
	click("☆ Favoritar")
	eq(p.favorites.ball, true)
	truthy(findButton("Vender 1"):GetAttribute("Disabled"), "venda bloqueada")
	click("★ Favorito")
	click("Vender 1")
	eq(p.inventory.ball, 2)
	UI.close(true)
end)

test("melhorias pela interface", function()
	S.pds.getProfile(hero).coins = 5000
	S.pds.markDirty(hero)
	M.advance(0.5)
	UI.open("Upgrades")
	M.advance(0.3)
	click("COMPRAR", true)
	local total = 0
	for _, lvl in pairs(S.pds.getProfile(hero).upgrades) do
		total = total + lvl
	end
	eq(total, 1)
	UI.close(true)
end)

test("presente diário pela interface", function()
	UI.open("Missions")
	M.advance(0.3)
	click("RESGATAR")
	eq(S.pds.getProfile(hero).gift.streak, 1)
	UI.close(true)
end)

test("coleção mostra silhuetas, progresso e aba de títulos", function()
	UI.open("Collection")
	M.advance(0.3)
	truthy(screenText("???"), "não descobertos")
	truthy(screenText("Descobertos"), "progresso")
	click("🏷️ Títulos")
	truthy(screenText("Lenda da Coleção"))
	UI.close(true)
end)

test("configurações: alternar opção salva no servidor", function()
	UI.open("Settings")
	M.advance(0.3)
	local b
	for _, d in ipairs(hero.PlayerGui.SettingsUI:GetDescendants()) do
		if d.Name == "autoSkip" then
			b = d
		end
	end
	b.Activated:Fire()
	M.advance(0.6)
	eq(S.pds.getProfile(hero).settings.autoSkip, true)
	UI.close(true)
end)

test("ranking recebe o cache do servidor", function()
	M.advance(16)
	UI.open("Ranking")
	M.advance(0.3)
	truthy(Store.leaderboard and Store.leaderboard.server, "cache")
	truthy(screenText("Hero"), "nome no ranking")
	UI.close(true)
end)

test("avisos do servidor aparecem como notificação", function()
	S.remote("Notify"):FireClient(hero, { text = "Teste de aviso 123", kind = "info" })
	M.advance(0.3)
	truthy(screenText("Teste de aviso 123"))
end)

test("nenhum aviso inesperado", function()
	local unexpected = {}
	for _, w in ipairs(M.warnings or {}) do
		if not (string.find(w, "UpdateAsync falhou") or string.find(w, "travado por outro servidor") or string.find(w, "MODO MEMÓRIA") or string.find(w, "falha simulada") or string.find(w, "reparado")) then
			table.insert(unexpected, w)
		end
	end
	eq(#unexpected, 0, table.concat(unexpected, " | "))
end)

print(string.format("\n%d passaram, %d falharam", passed, failed))
return failed == 0
