-- Teste de fumaça do SERVIDOR real (src/server + src/shared) num ambiente Roblox simulado.
-- Cobre: carga/gravação com trava de sessão, remotes, deduplicação de pedidos, limite de
-- frequência, abertura automática, venda/banco via remotes, falhas de DataStore,
-- desconexão, reinício do servidor (persistência) e vários jogadores simultâneos.

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
	mount(RS, "Shared", "src/shared")
	local server = mount(g:GetService("ServerScriptService"), "Server", "src/server")
	local main = server:FindFirstChild("Main")
	M.run(function()
		require(main)
	end)
	return {
		remote = function(name)
			return RS:FindFirstChild("Remotes"):FindFirstChild(name)
		end,
		pds = moduleCache[server.Services.PlayerDataService],
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

local STORE = "CaseStrike_Profiles_v1"

---------------------------------------------------------------------------
print("== Servidor simulado ==")

local S = bootServer("job-A")
local alice = M.newPlayer(101, "Alice")
M.addPlayer(alice)
M.advance(2)

test("servidor inicia, cria remotes e lobby sem erros", function()
	truthy(S.remote("RequestCaseOpen"))
	truthy(S.remote("DataUpdated"))
	truthy(workspace:FindFirstChild("Lobby"), "lobby construído")
end)

test("perfil carrega com trava de sessão e envia fotografia", function()
	truthy(S.pds.isLoaded(alice))
	local rec = M.datastore[STORE]["p_101"]
	truthy(rec and rec.lock and rec.lock.jobId == "job-A", "trava gravada")
	local v = lastView(alice)
	truthy(v, "DataUpdated enviado")
	eq(v.credits, 500)
	truthy(alice:FindFirstChild("leaderstats"))
end)

test("abrir caixa via remote desconta e entrega", function()
	local res = invoke(S, "RequestCaseOpen", alice, { action = "open", caseId = "urban", quantity = 1, requestId = "req-1" })
	truthy(res.ok, tostring(res.message))
	eq(#res.data.results, 1)
	eq(S.pds.getProfile(alice).credits, 475)
end)

test("pedido repetido (mesmo requestId) não cobra duas vezes", function()
	local res = invoke(S, "RequestCaseOpen", alice, { action = "open", caseId = "urban", quantity = 1, requestId = "req-1" })
	truthy(res.ok)
	eq(S.pds.getProfile(alice).credits, 475)
end)

test("intervalo mínimo entre aberturas é aplicado pelo servidor", function()
	M.advance(1.2)
	local r1 = invoke(S, "RequestCaseOpen", alice, { action = "open", caseId = "urban", quantity = 1 })
	truthy(r1.ok)
	local r2 = invoke(S, "RequestCaseOpen", alice, { action = "open", caseId = "urban", quantity = 1 })
	eq(r2.ok, false)
	eq(r2.error, "rate_limited")
	eq(S.pds.getProfile(alice).credits, 450)
end)

test("pedidos malformados são rejeitados sem alterar nada", function()
	local before = S.pds.getProfile(alice).credits
	for _, payload in ipairs({
		"lixo",
		{ action = 12 },
		{ action = "open", caseId = "urban", quantity = 3 },
		{ action = "open", caseId = "../x", quantity = 1 },
		{ action = "open", caseId = "urban", quantity = 1, cost = -999999 },
		{ action = "inexistente" },
	}) do
		M.advance(1.2)
		local res = invoke(S, "RequestCaseOpen", alice, payload)
		if type(payload) == "table" and payload.cost then
			-- valores econômicos do cliente são ignorados: cobra o preço real
			truthy(res.ok)
			before = before - 25
		else
			eq(res.ok, false)
		end
	end
	eq(S.pds.getProfile(alice).credits, before)
end)

test("venda via remote e proteção contra repetição", function()
	local profile = S.pds.getProfile(alice)
	local uid
	for u in pairs(profile.inventory) do
		uid = u
		break
	end
	local credits = profile.credits
	local res = invoke(S, "InventoryAction", alice, { action = "sell", uids = { uid } })
	truthy(res.ok, tostring(res.message))
	local again = invoke(S, "InventoryAction", alice, { action = "sell", uids = { uid } })
	eq(again.ok, false)
	eq(S.pds.getProfile(alice).credits, credits + res.data.credits)
end)

test("banco via remotes: depositar, render, resgatar", function()
	local profile = S.pds.getProfile(alice)
	local uid
	for u in pairs(profile.inventory) do
		uid = u
		break
	end
	truthy(invoke(S, "BankAction", alice, { action = "deposit", uid = uid }).ok)
	M.epoch = M.epoch + 3600 -- uma hora depois (relógio do servidor)
	local res = invoke(S, "BankAction", alice, { action = "claim" })
	truthy(res.ok, tostring(res.message))
	truthy(res.data.credits > 0)
	local sell = invoke(S, "InventoryAction", alice, { action = "sell", uids = { uid } })
	eq(sell.error, "item_in_bank")
end)

test("abertura automática respeita início/parada", function()
	S.pds.getProfile(alice).credits = 10000
	M.advance(2)
	local noAuto = invoke(S, "RequestCaseOpen", alice, { action = "open", caseId = "urban", quantity = 1, auto = true })
	eq(noAuto.error, "auto_inactive")
	truthy(invoke(S, "RequestCaseOpen", alice, { action = "startAuto", caseId = "urban", quantity = 1 }).ok)
	for _ = 1, 3 do
		M.advance(2)
		local r = invoke(S, "RequestCaseOpen", alice, { action = "open", caseId = "urban", quantity = 1, auto = true })
		truthy(r.ok, tostring(r.message))
	end
	truthy(invoke(S, "RequestCaseOpen", alice, { action = "stopAuto" }).ok)
	M.advance(2)
	local after = invoke(S, "RequestCaseOpen", alice, { action = "open", caseId = "urban", quantity = 1, auto = true })
	eq(after.error, "auto_inactive", "interrompida imediatamente")
end)

test("vários jogadores simultâneos não interferem", function()
	local bob = M.newPlayer(202, "Bob")
	local cara = M.newPlayer(303, "Cara")
	M.addPlayer(bob)
	M.addPlayer(cara)
	M.advance(2)
	local ra = invoke(S, "RequestCaseOpen", bob, { action = "open", caseId = "urban", quantity = 5 })
	local rc = invoke(S, "RequestCaseOpen", cara, { action = "open", caseId = "starter", quantity = 1 })
	truthy(ra.ok and rc.ok)
	eq(S.pds.getProfile(bob).credits, 375)
	eq(S.pds.getProfile(cara).credits, 490)
	local n = 0
	for _ in pairs(S.pds.getProfile(bob).inventory) do
		n = n + 1
	end
	eq(n, 5)
	local lb = invoke(S, "LeaderboardRequest", bob, { action = "get" })
	truthy(lb.ok and #lb.data.server == 3)
end)

test("salvamento automático grava o inventário", function()
	M.advance(65)
	local rec = M.datastore[STORE]["p_202"]
	truthy(rec and rec.data, "dados gravados")
	local n = 0
	for _ in pairs(rec.data.inventory) do
		n = n + 1
	end
	eq(n, 5)
end)

test("falhas temporárias do DataStore são repetidas", function()
	local bob = M.players[202]
	invoke(S, "RequestCaseOpen", bob, { action = "open", caseId = "urban", quantity = 1 })
	M.failNext = 2
	M.advance(70)
	local n = 0
	for _ in pairs(M.datastore[STORE]["p_202"].data.inventory) do
		n = n + 1
	end
	eq(n, 6)
	eq(M.failNext, 0)
end)

test("desconexão grava e libera a trava", function()
	local cara = M.players[303]
	local inv = S.pds.getProfile(cara).inventory
	M.removePlayer(cara)
	M.advance(3)
	local rec = M.datastore[STORE]["p_303"]
	eq(rec.lock, nil, "trava liberada")
	local n, m = 0, 0
	for _ in pairs(rec.data.inventory) do
		n = n + 1
	end
	for _ in pairs(inv) do
		m = m + 1
	end
	eq(n, m)
	eq(S.pds.getProfile(cara), nil)
end)

test("perfil travado por outro servidor não é carregado nem sobrescrito", function()
	M.datastore[STORE]["p_404"] = { data = { credits = 999, inventory = {} }, lock = { jobId = "job-OUTRO", time = M.epoch + M.clock } }
	local dave = M.newPlayer(404, "Dave")
	M.addPlayer(dave)
	M.advance(60)
	truthy(dave.kicked, "jogador desconectado com aviso")
	eq(M.datastore[STORE]["p_404"].data.credits, 999)
	eq(M.datastore[STORE]["p_404"].lock.jobId, "job-OUTRO")
end)

test("trava perdida no meio da sessão impede sobrescrever", function()
	local bob = M.players[202]
	M.datastore[STORE]["p_202"].lock = { jobId = "job-INVASOR", time = M.epoch + M.clock }
	M.datastore[STORE]["p_202"].data.credits = 4242
	M.advance(65)
	eq(M.datastore[STORE]["p_202"].data.credits, 4242, "não sobrescreveu")
	truthy(bob.kicked)
end)

-- desligamento do servidor
local aliceInventory = {}
for uid, item in pairs(S.pds.getProfile(alice).inventory) do
	aliceInventory[uid] = item.defId
end
local aliceCredits = S.pds.getProfile(alice).credits
test("BindToClose grava todos os jogadores", function()
	M.run(function()
		for _, fn in ipairs(M.closeHandlers) do
			fn()
		end
	end)
	local rec = M.datastore[STORE]["p_101"]
	eq(rec.lock, nil)
	eq(rec.data.credits, aliceCredits)
end)

print("== Reinício do servidor ==")
local S2 = bootServer("job-B")
local alice2 = M.newPlayer(101, "Alice")
M.addPlayer(alice2)
M.advance(2)

test("inventário e saldo persistem após reinício", function()
	local p = S2.pds.getProfile(alice2)
	truthy(p, "carregou")
	eq(p.credits, aliceCredits)
	for uid, defId in pairs(aliceInventory) do
		truthy(p.inventory[uid], "item " .. uid)
		eq(p.inventory[uid].defId, defId)
	end
	local v = lastView(alice2)
	truthy(v and v.wealth.netWorth >= p.credits)
end)

test("nenhum aviso inesperado no servidor", function()
	local unexpected = {}
	for _, w in ipairs(M.warnings or {}) do
		if not string.find(w, "UpdateAsync falhou") and not string.find(w, "travado por outro servidor") and not string.find(w, "trava perdida") then
			table.insert(unexpected, w)
		end
	end
	eq(#unexpected, 0, table.concat(unexpected, " | "))
end)

---------------------------------------------------------------------------
print("== Cliente simulado (interface real conectada ao servidor) ==")

local Players = game:GetService("Players")
rawset(Players, "LocalPlayer", alice2)
M.localPlayer = alice2
S2.pds.getProfile(alice2).credits = 50000
S2.pds.getProfile(alice2).level = 20

local clientFolder = mount(M.instance("Folder", "StarterPlayerScripts"), "Client", "src/client")
local clientOk, clientErr = pcall(function()
	M.run(function()
		require(clientFolder:FindFirstChild("Main"))
	end)
end)
M.advance(3)
local UI = moduleCache[clientFolder.Controllers.UIController]
local Store = moduleCache[clientFolder.Util.Store]

local function guiRoot()
	return alice2.PlayerGui
end
-- procura primeiro nos diálogos e na roleta, depois nos painéis e por fim no HUD
local function screensInOrder()
	local first, last, middle = {}, {}, {}
	for _, g in ipairs(alice2.PlayerGui:GetChildren()) do
		if g.Name == "Dialogs" or g.Name == "CaseOpening" then
			table.insert(first, g)
		elseif g.Name == "MainHUD" or g.Name == "Toasts" then
			table.insert(last, g)
		else
			table.insert(middle, g)
		end
	end
	table.sort(first, function(a, b)
		return a.Name == "Dialogs"
	end)
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
	M.advance(0.5)
	return b
end
local function profile()
	return S2.pds.getProfile(alice2)
end
local function itemCount()
	local n = 0
	for _ in pairs(profile().inventory) do
		n = n + 1
	end
	return n
end

test("cliente inicia sem erros e recebe a fotografia", function()
	truthy(clientOk, tostring(clientErr))
	for _, name in ipairs({ "MainHUD", "CaseOpening", "Dialogs" }) do
		truthy(guiRoot():FindFirstChild(name), "ScreenGui " .. name)
	end
	truthy(Store.view, "fotografia recebida")
	eq(Store.view.credits, 50000)
end)

test("todos os painéis abrem e atualizam sem erros", function()
	for _, name in ipairs({ "Shop", "Inventory", "Bank", "Upgrade", "Collections", "Missions", "Gifts", "Luck", "Attributes", "Rebirth", "Leaderboard", "Battle", "Zones", "Potions" }) do
		UI.open(name)
		M.advance(0.3)
		eq(UI.current, name)
	end
	UI.open("CaseWindow", { caseId = "neon" })
	M.advance(0.5)
	UI.close()
	eq(UI.current, nil)
end)

test("apenas um painel aberto por vez", function()
	UI.open("Shop")
	UI.open("Bank")
	M.advance(0.3) -- deixa terminar a animação de fechamento de painéis anteriores
	local visible = 0
	for _, d in ipairs(guiRoot():GetDescendants()) do
		if d.Name == "Panel" and d.Visible then
			visible = visible + 1
		end
	end
	eq(visible, 1)
	for _, name in ipairs({ "CaseShop", "Bank", "Inventory", "UpgradeWorkshop", "Collections", "Missions", "Rewards", "Rankings" }) do
		truthy(guiRoot():FindFirstChild(name), "ScreenGui " .. name)
	end
	UI.close()
end)

test("fluxo: loja → janela da caixa → ABRIR → roleta → item no inventário", function()
	local before = itemCount()
	local credits = profile().credits
	UI.open("Shop")
	M.advance(0.2)
	UI.open("CaseWindow", { caseId = "urban" })
	M.advance(0.5)
	click("ABRIR ×1")
	M.advance(8)
	eq(itemCount(), before + 1)
	eq(profile().credits, credits - 25)
	truthy(findButton("✔ Guardar"), "revelação exibida")
	click("✔ Guardar")
end)

test("fluxo: abrir ×10 com confirmação do custo total", function()
	local before = itemCount()
	UI.open("CaseWindow", { caseId = "tactical" })
	M.advance(0.5)
	click("×10")
	click("ABRIR ×10")
	truthy(findButton("Abrir"), "diálogo de confirmação")
	click("Abrir")
	M.advance(8)
	eq(itemCount(), before + 10)
	click("✔ Guardar")
end)

test("fluxo: abertura automática inicia e para pelo botão", function()
	local before = profile().stats.casesOpened
	UI.open("CaseWindow", { caseId = "urban" })
	M.advance(0.5)
	click("×1")
	click("🔁 Abertura automática")
	click("Iniciar")
	M.advance(25)
	local during = profile().stats.casesOpened
	truthy(during > before + 2, "abriu várias: " .. (during - before))
	click("⏹ PARAR")
	M.advance(12)
	local after = profile().stats.casesOpened
	truthy(after - during <= 1, "parou (no máximo a abertura em andamento)")
	UI.close()
end)

test("fluxo: inventário → favoritar, equipar, depositar, retirar", function()
	UI.open("Inventory")
	M.advance(0.5)
	local card
	for _, d in ipairs(guiRoot():FindFirstChild("Inventory"):GetDescendants()) do
		if d:IsA("TextButton") and d.Visible and d.Text == "" and d.LayoutOrder == 1 and d.Parent and d.Parent:FindFirstChild("UIGridLayout") then
			card = d
			break
		end
	end
	assert(card, "cartão do inventário")
	card.Activated:Fire()
	M.advance(0.3)
	click("⭐ Favoritar")
	local fav = 0
	for _, it in pairs(profile().inventory) do
		if it.favorite then
			fav = fav + 1
		end
	end
	eq(fav, 1)
	click("🎽 Equipar")
	local bankBefore = 0
	for _, it in pairs(profile().inventory) do
		if it.location == "bank" then
			bankBefore = bankBefore + 1
		end
	end
	click("🏦 Depositar")
	local inBank = -bankBefore
	for _, it in pairs(profile().inventory) do
		if it.location == "bank" then
			inBank = inBank + 1
		end
	end
	eq(inBank, 1)
	click("↩ Retirar do banco")
	click("₵ Vender")
	truthy(findButton("Vender favorita"), "favorita exige confirmação digitada")
	local confirmBtn = findButton("Vender favorita")
	confirmBtn.Activated:Fire()
	M.advance(0.5)
	local still = 0
	for _, it in pairs(profile().inventory) do
		if it.favorite then
			still = still + 1
		end
	end
	eq(still, 1, "sem digitar VENDER nada é vendido")
	click("Cancelar")
	UI.close()
end)

test("fluxo: banco resgata e oficina aplica melhoria garantida", function()
	local p = profile()
	p.materials.scrap = 100
	p.materials.pigment = 20
	UI.open("Bank")
	M.advance(0.5)
	click("Depositar")
	M.epoch = M.epoch + 600
	click("RESGATAR")
	truthy(p.stats.bankClaimedTotal > 0, "resgatou")
	UI.close()
	local uid
	for u, it in pairs(p.inventory) do
		if it.location == "inventory" then
			uid = u
			break
		end
	end
	UI.open("Upgrade", { uid = uid })
	M.advance(0.5)
	click("Aplicar")
	click("Aplicar")
	truthy(p.inventory[uid].upgrades.finish, "melhoria aplicada")
	UI.close()
end)

test("fluxo: presentes diários e missões pela interface", function()
	UI.open("Gifts")
	M.advance(0.5)
	click("Resgatar dia", true)
	eq(profile().rewards.dailyStreak, 1)
	UI.close()
end)

test("HUD mostra patrimônio, saldo e nível atualizados", function()
	M.advance(1)
	local v = Store.view
	truthy(v.wealth.netWorth >= v.credits)
	local found = false
	for _, d in ipairs(guiRoot():GetDescendants()) do
		if d:IsA("TextLabel") and d.Text and string.find(d.Text, "Nível " .. v.level, 1, true) then
			found = true
		end
	end
	truthy(found, "barra de XP com nível")
end)

test("V4: abrir ×25 mostra só a grade de prêmios (sem 25 animações)", function()
	local p = profile()
	p.attributes.multiOpen = 1
	p.credits = p.credits + 5000
	S2.pds.push(alice2)
	M.advance(0.5)
	local before = itemCount()
	UI.open("CaseWindow", { caseId = "starter" })
	M.advance(0.5)
	click("×25")
	click("ABRIR ×25")
	click("Abrir")
	M.advance(3)
	eq(itemCount(), before + 25)
	for _, d in ipairs(guiRoot():FindFirstChild("CaseOpening"):GetDescendants()) do
		if d.Name == "Strip1" then
			eq(d.Parent.Visible, false, "faixas da roleta ocultas no ×25")
		end
	end
	truthy(findButton("✔ Guardar"), "grade de prêmios exibida")
	click("✔ Guardar")
end)

test("V4: inspeção 3D com aproximar/afastar", function()
	UI.open("Inventory")
	M.advance(0.5)
	local card
	for _, d in ipairs(guiRoot():FindFirstChild("Inventory"):GetDescendants()) do
		if d:IsA("TextButton") and d.Visible and d.Text == "" and d.LayoutOrder == 1 and d.Parent and d.Parent:FindFirstChild("UIGridLayout") then
			card = d
			break
		end
	end
	card.Activated:Fire()
	M.advance(0.3)
	click("🔍 Inspecionar")
	click("＋ Aproximar")
	click("－ Afastar")
	click("↺ Girar automático")
	click("✕ Fechar inspeção")
	eq(findButton("✕ Fechar inspeção"), nil)
end)

test("V4: expor no showroom cria a vitrine visível a todos", function()
	truthy(alice2:GetAttribute("ShowroomBooth"), "vitrine atribuída")
	local target
	for uid, it in pairs(profile().inventory) do
		if it.location == "inventory" and not it.showcase then
			target = uid
			break
		end
	end
	UI.close(true)
	UI.open("Inventory", { uid = target })
	M.advance(0.5)
	click("🖼 Expor no showroom")
	M.advance(1)
	local booth = workspace.Lobby.Showroom.Booths:FindFirstChild("Booth" .. alice2:GetAttribute("ShowroomBooth"))
	local display = booth:FindFirstChild("Display")
	truthy(display, "vitrine montada")
	local pedestals = 0
	for _, d in ipairs(display:GetChildren()) do
		if d.Name == "Pedestal" then
			pedestals = pedestals + 1
		end
	end
	eq(pedestals, 1)
	UI.close()
end)

test("V4: atributos pela interface e efeitos reduzidos", function()
	local p = profile()
	p.credits = p.credits + 100000
	UI.open("Attributes")
	M.advance(0.5)
	local before = p.attributes.luck
	click("Melhorar")
	truthy(p.attributes.luck == before + 1 or p.bank.upgrades.efficiency > 0, "atributo comprado")
	click("🌙 Reduzir efeitos visuais", true)
	eq(p.settings.reduceEffects, true)
	UI.close()
end)

test("V4: venda de Secreta exige confirmação explícita no servidor", function()
	local p = profile()
	local uid = "i" .. p.nextUid
	p.nextUid = p.nextUid + 1
	p.inventory[uid] = { uid = uid, defId = "phantom_05", obtainedAt = 0, favorite = false, equipped = false, location = "inventory", upgrades = {} }
	local res = invoke(S2, "InventoryAction", alice2, { action = "sell", uids = { uid } })
	eq(res.error, "valuable_locked")
	truthy(p.inventory[uid])
	local ok = invoke(S2, "InventoryAction", alice2, { action = "sell", uids = { uid }, confirmValuable = true })
	truthy(ok.ok)
end)

test("V4: placa acima do personagem mostra nome, título, nível e patrimônio", function()
	local character = M.instance("Model", "Alice")
	local head = M.instance("Part", "Head")
	head.Parent = character
	local hrp = M.instance("Part", "HumanoidRootPart")
	hrp.Position = Vector3.new(0, 3, 9)
	hrp.Parent = character
	alice2.Character = character
	alice2.CharacterAdded:Fire(character)
	M.advance(0.5)
	local plate = head:FindFirstChild("CollectorPlate")
	truthy(plate, "placa criada")
	eq(plate.PlayerName.Text, "Alice")
	truthy(string.find(plate.Stats.Text, "Nv ", 1, true))
end)

test("zonas: servidor detecta a posição e só dá sorte com a zona desbloqueada", function()
	local p = profile()
	local hrp = alice2.Character.HumanoidRootPart
	hrp.Position = Vector3.new(235, 3, 0) -- dentro da Zona 2
	M.advance(1.5)
	eq(alice2:GetAttribute("ZoneId"), "zone2")
	local odds = invoke(S2, "RequestCaseOpen", alice2, { action = "odds", caseId = "starter" })
	local luckLocked = odds.data.luck
	p.credits = p.credits + 10000
	local buy = invoke(S2, "ProgressionAction", alice2, { action = "buyZone", zoneId = "zone2" })
	truthy(buy.ok, tostring(buy.message))
	local odds2 = invoke(S2, "RequestCaseOpen", alice2, { action = "odds", caseId = "starter" })
	truthy(odds2.data.luck > luckLocked, "sorte da zona aplicada")
	hrp.Position = Vector3.new(0, 3, 9)
	M.advance(1.5)
	eq(alice2:GetAttribute("ZoneId"), "zone1")
	local odds3 = invoke(S2, "RequestCaseOpen", alice2, { action = "odds", caseId = "starter" })
	truthy(odds3.data.luck < odds2.data.luck, "fora da zona sem bônus")
end)

test("poções: ativar pela interface e efeito com tempo", function()
	local p = profile()
	p.potions.luck = 2
	S2.pds.push(alice2)
	M.advance(0.5)
	UI.open("Potions")
	M.advance(0.5)
	click("Ativar " .. "Poção da Sorte")
	eq(p.potions.luck, 1)
	truthy(p.activePotions.luck > M.epoch + M.clock, "efeito ativo")
	UI.close()
end)

test("loja em seções e estoque limitado diário", function()
	local p = profile()
	p.level = 25
	p.credits = p.credits + 10000000
	UI.open("Shop")
	M.advance(0.5)
	for i = 1, 5 do
		local r = invoke(S2, "RequestCaseOpen", alice2, { action = "open", caseId = "lucky", quantity = 1 })
		truthy(r.ok, tostring(r.message))
		M.advance(1.2)
	end
	local r6 = invoke(S2, "RequestCaseOpen", alice2, { action = "open", caseId = "lucky", quantity = 1 })
	eq(r6.error, "out_of_stock")
	UI.close()
end)

test("índice por raridade e loja com seções", function()
	UI.open("Collections")
	M.advance(0.5)
	click("Ver por raridade")
	truthy(findButton("Ver por coleção"), "modo raridade ativo")
	UI.close(true)
	UI.open("Shop")
	M.advance(0.3)
	local found = {}
	for _, d in ipairs(guiRoot():FindFirstChild("CaseShop"):GetDescendants()) do
		if d:IsA("TextLabel") and d.Text and string.find(d.Text, "~ ", 1, true) then
			found[d.Text] = true
		end
	end
	truthy(found["~ Caixas de Nível ~"] and found["~ Caixas Especiais ~"] and found["~ Estoque Limitado ~"], "três seções")
	UI.close(true)
end)

test("nenhum aviso inesperado no cliente", function()
	local unexpected = {}
	for _, w in ipairs(M.warnings or {}) do
		if not string.find(w, "UpdateAsync falhou") and not string.find(w, "travado por outro servidor") and not string.find(w, "trava perdida") then
			table.insert(unexpected, w)
		end
	end
	eq(#unexpected, 0, table.concat(unexpected, " | "))
end)

print(string.format("\n%d passaram, %d falharam", passed, failed))
return failed == 0
