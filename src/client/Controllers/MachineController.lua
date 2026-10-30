-- Máquinas no cliente:
-- * painel "Machines" (lista das 4 máquinas, status e atalho para ir até elas);
-- * painel "Machine" (máquina selecionada, preço, CHANCES REAIS, botão USAR MÁQUINA e resultado);
-- * animação 3D da máquina (luzes, cápsulas, objeto aparecendo no compartimento) para quem usou
--   e para quem está olhando (MachineResult);
-- * camada RewardUI com brilho/faixa especial para Lendário e Secreto.
-- O resultado chega do servidor ANTES da animação; "PULAR" só adianta a exibição.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MachineDefinitions = require(Shared.MachineDefinitions)
local ItemDefinitions = require(Shared.ItemDefinitions)
local RarityConfig = require(Shared.RarityConfig)
local Odds = require(Shared.Logic.Odds)
local ItemModels = require(Shared.Visual.ItemModels)
local Format = require(Shared.Util.Format)

local UI = require(script.Parent.Parent.Util.UI)
local Store = require(script.Parent.Parent.Util.Store)
local Net = require(script.Parent.Parent.Util.Net)
local Sounds = require(script.Parent.Parent.Util.Sounds)
local UIController = require(script.Parent.UIController)

local MachineController = {}

local localPlayer = Players.LocalPlayer
local selected = "common"
local state = { phase = "idle" } -- idle | rolling | result
local panel = {}
local machineAnims = {} -- [machineId] = { token, skip }

---------------------------------------------------------------------------
-- animação 3D da máquina
---------------------------------------------------------------------------
local function machineModel(machineId)
	local world = workspace:FindFirstChild("MysteryPark")
	local folder = world and world:FindFirstChild("Machines")
	return folder and folder:FindFirstChild("Machine_" .. machineId)
end

local function spawnPrize(model, itemId, rarityId)
	local tray = model:FindFirstChild("TrayPoint")
	if not tray then
		return
	end
	local old = model:FindFirstChild("Prize")
	if old then
		old:Destroy()
	end
	local prize = ItemModels.build(itemId)
	prize.Name = "Prize"
	prize:PivotTo(tray.CFrame)
	local rarity = RarityConfig.get(rarityId)
	if rarity and rarity.effect and Store.setting("effects") ~= false then
		local glow = Instance.new("PointLight")
		glow.Color = rarity.color
		glow.Range = 14
		glow.Brightness = 3
		glow.Parent = prize.PrimaryPart
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new(rarity.color)
		sparkles.Rate = rarity.effect == "secret" and 30 or 18
		sparkles.Lifetime = NumberRange.new(0.6, 1.2)
		sparkles.Speed = NumberRange.new(2, 5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.3)
		sparkles.LightEmission = 1
		sparkles.Parent = prize.PrimaryPart
	end
	prize.Parent = model
	task.delay(6, function()
		if prize.Parent then
			prize:Destroy()
		end
	end)
	return prize
end

-- toca a animação da máquina; termina sozinha após `duration` ou quando anim.skip = true
function MachineController.animateMachine(machineId, duration, itemId, rarityId)
	local model = machineModel(machineId)
	if not model then
		return nil
	end
	local previous = machineAnims[machineId]
	if previous then
		previous.skip = true
	end
	local anim = { skip = false, done = false }
	machineAnims[machineId] = anim
	local def = MachineDefinitions.get(machineId)
	local lights = model:FindFirstChild("Lights")
	local capsules = model:FindFirstChild("Capsules")
	local visorLight = model:FindFirstChild("VisorBack") and model.VisorBack:FindFirstChild("VisorLight")
	local spinSound = Sounds.playAt("spin", model:FindFirstChild("Body"))
	local capsuleColors = {}
	if capsules then
		for i, c in ipairs(capsules:GetChildren()) do
			capsuleColors[i] = c.Color
		end
	end
	task.spawn(function()
		local elapsed, step = 0, 0
		while elapsed < duration and not anim.skip do
			step = step + 1
			if lights then
				for i, l in ipairs(lights:GetChildren()) do
					l.Color = ((i + step) % 2 == 0) and Color3.fromRGB(255, 255, 255) or def.lightColor
				end
			end
			if capsules then
				local list = capsules:GetChildren()
				for i, c in ipairs(list) do
					c.Color = capsuleColors[((i + step) % #list) + 1]
				end
			end
			if visorLight then
				visorLight.Brightness = (step % 2 == 0) and 3 or 1.5
			end
			elapsed = elapsed + task.wait(0.12)
		end
		if spinSound then
			spinSound:Stop()
		end
		if lights then
			for _, l in ipairs(lights:GetChildren()) do
				l.Color = RarityConfig.get(rarityId) and RarityConfig.get(rarityId).color or def.lightColor
			end
		end
		if visorLight then
			visorLight.Brightness = 1
		end
		spawnPrize(model, itemId, rarityId)
		Sounds.playAt("reveal", model:FindFirstChild("Body"))
		anim.done = true
		task.delay(3, function()
			if machineAnims[machineId] == anim and lights then
				for _, l in ipairs(lights:GetChildren()) do
					l.Color = def.lightColor
				end
			end
		end)
	end)
	return anim
end

---------------------------------------------------------------------------
-- camada de revelação (RewardUI)
---------------------------------------------------------------------------
local rewardGui, flash, banner

local function showReveal(rarityId)
	local rarity = RarityConfig.get(rarityId)
	if not rarity or not rarity.effect or Store.setting("effects") == false then
		return
	end
	if not rewardGui then
		rewardGui = UIController.screen("RewardUI", 10)
		flash = UI.make("Frame", { Name = "Flash", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = rewardGui })
		banner = UI.label(rewardGui, "", {
			Name = "Banner",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.16, 0),
			Size = UDim2.new(0, 700, 0, 70),
			Font = Enum.Font.FredokaOne,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0,
			MaxText = 60,
			Visible = false,
		})
	end
	flash.BackgroundColor3 = rarity.color
	flash.BackgroundTransparency = 0.35
	banner.Text = rarity.effect == "secret" and "🔴 OBJETO SECRETO! 🔴" or "🌟 LENDÁRIO! 🌟"
	banner.TextColor3 = rarity.color
	banner.Visible = true
	Sounds.play("legendary")
	task.spawn(function()
		for i = 1, 6 do
			flash.BackgroundTransparency = 0.35 + i * 0.11
			task.wait(0.08)
		end
		flash.BackgroundTransparency = 1
		task.wait(2)
		banner.Visible = false
	end)
end

---------------------------------------------------------------------------
-- painel da máquina
---------------------------------------------------------------------------
local function setResultButtons(visible)
	for _, b in ipairs({ panel.sellButton, panel.favButton, panel.showButton }) do
		b.Visible = visible
	end
end

local function showItem(itemId, silhouette)
	ItemModels.showInViewport(panel.viewport, itemId, silhouette)
end

local function refreshMachinePanel(view)
	local def = MachineDefinitions.get(selected)
	panel.titleLabel.Text = "🎰 " .. def.name
	panel.priceLabel.Text = "Preço: 💰 " .. Format.int(def.price) .. " Coins   •   Nível " .. def.level .. "+"
	local unlocked = view.level >= def.level
	local full = view.itemCount >= view.capacity
	if state.phase == "rolling" then
		panel.useButton.Visible = false
		panel.skipButton.Visible = true
	else
		panel.useButton.Visible = true
		panel.skipButton.Visible = false
		if not unlocked then
			panel.useButton.Text = "🔒 NÍVEL " .. def.level
			UI.setEnabled(panel.useButton, false)
		elseif full then
			panel.useButton.Text = "INVENTÁRIO CHEIO"
			UI.setEnabled(panel.useButton, false)
		else
			panel.useButton.Text = "USAR MÁQUINA  💰" .. Format.int(def.price)
			UI.setEnabled(panel.useButton, view.coins >= def.price, UI.Theme.green)
		end
	end
	panel.footer.Text = "Seus Coins: 💰 " .. Format.int(view.coins) .. "   •   Inventário " .. view.itemCount .. "/" .. view.capacity
	if state.phase == "result" and state.result then
		local itemId = state.result.itemId
		local owned = view.inventory[itemId] or 0
		panel.favButton.Text = view.favorites[itemId] and "★ FAVORITO" or "☆ FAVORITAR"
		panel.sellButton.Text = "VENDER 💰" .. Format.int(ItemDefinitions.get(itemId).value)
		UI.setEnabled(panel.sellButton, owned > 0 and not view.favorites[itemId], UI.Theme.coins)
		UI.setEnabled(panel.favButton, owned > 0, UI.Theme.blue)
		UI.setEnabled(panel.showButton, owned > 0, UI.Theme.accent)
	end
end

local function buildOddsList(machineId)
	for _, c in ipairs(panel.oddsList:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local view = Store.view
	for i, row in ipairs(Odds.display(machineId)) do
		local rarity = RarityConfig.get(row.rarity)
		local f = UI.frame(panel.oddsList, { Name = "Odds_" .. row.item, Size = UDim2.new(1, -6, 0, 52), LayoutOrder = i })
		UI.frame(f, { Size = UDim2.new(0, 8, 1, -12), Position = UDim2.new(0, 6, 0, 6), BackgroundColor3 = rarity.color, radius = 4 })
		local known = view and view.discovered[row.item]
		UI.label(f, (known and "" or "❔ ") .. row.name, { Position = UDim2.new(0, 22, 0, 4), Size = UDim2.new(0.62, -22, 0, 26), MaxText = 20 })
		UI.label(f, rarity.name .. " • 💰" .. Format.int(row.value), { Position = UDim2.new(0, 22, 0, 30), Size = UDim2.new(0.62, -22, 0, 18), TextColor3 = rarity.color, MaxText = 15 })
		UI.label(f, Format.percent(row.chance), { Name = "Chance", Position = UDim2.new(0.62, 0, 0, 0), Size = UDim2.new(0.38, -12, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.FredokaOne, MaxText = 26 })
	end
end

local function finishRoll()
	if state.phase ~= "rolling" then
		return
	end
	local result = state.result
	state.phase = "result"
	if state.anim then
		state.anim.skip = true
	end
	local item = ItemDefinitions.get(result.itemId)
	local rarity = RarityConfig.get(result.rarity)
	showItem(result.itemId, false)
	panel.status.Text = (result.isNew and "✨ NOVO! " or "") .. item.name
	panel.rarityLabel.Text = rarity.name .. "   •   Valor 💰" .. Format.int(item.value)
	panel.rarityLabel.TextColor3 = rarity.color
	setResultButtons(true)
	showReveal(result.rarity)
	Sounds.play("reveal")
	if UIController.current ~= "Machine" then
		UIController.toast("🎁 Você recebeu " .. item.name .. " (" .. rarity.name .. ")", result.rarity == "secret" and "secret" or "info")
	end
	if Store.view then
		refreshMachinePanel(Store.view)
	end
end

function MachineController.skip()
	finishRoll()
end

function MachineController.use()
	if state.phase == "rolling" then
		return
	end
	local machineId = selected
	local response = Net.call("RequestMachineUse", { action = "use", machineId = machineId })
	if not response.ok then
		UIController.toast(response.message or "Não foi possível usar a máquina.", "warn")
		return response
	end
	state = { phase = "rolling", result = response }
	setResultButtons(false)
	panel.status.Text = "Sorteando..."
	panel.rarityLabel.Text = ""
	local duration = Store.setting("autoSkip") and 0.2 or response.duration
	state.anim = MachineController.animateMachine(machineId, duration, response.itemId, response.rarity)
	local myState = state
	if Store.view then
		refreshMachinePanel(Store.view)
	end
	-- "roleta" no visor do painel enquanto a máquina trabalha
	task.spawn(function()
		local pool = MachineDefinitions.get(machineId).pool
		local elapsed, i = 0, 0
		while state == myState and state.phase == "rolling" and elapsed < duration do
			i = i + 1
			showItem(pool[(i % #pool) + 1].item, true)
			elapsed = elapsed + task.wait(0.15)
		end
		if state == myState then
			finishRoll()
		end
	end)
	return response
end

local function buildMachinePanel(content, _, titleLabel)
	panel.titleLabel = titleLabel
	panel.priceLabel = UI.label(content, "", { Size = UDim2.new(1, 0, 0, 26), TextColor3 = UI.Theme.coins, MaxText = 22 })

	local left = UI.frame(content, { Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(0, 360, 1, -70), BackgroundColor3 = UI.Theme.bg })
	UI.label(left, "Chances reais desta máquina", { Position = UDim2.new(0, 10, 0, 6), Size = UDim2.new(1, -20, 0, 24), MaxText = 20 })
	panel.oddsList = UI.make("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 34), Size = UDim2.new(1, -10, 1, -74), Parent = left })
	UI.list(panel.oddsList, 4)
	UI.label(left, "Sorteio feito no servidor com exatamente estas chances.", {
		Position = UDim2.new(0, 10, 1, -36),
		Size = UDim2.new(1, -20, 0, 30),
		TextColor3 = UI.Theme.muted,
		TextWrapped = true,
		MaxText = 13,
	})

	local right = UI.make("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 372, 0, 34), Size = UDim2.new(1, -372, 1, -70), Parent = content })
	panel.viewport = UI.viewport(right, { Size = UDim2.new(1, 0, 0, 190) })
	panel.status = UI.label(right, "Pronto para jogar!", { Name = "Status", Position = UDim2.new(0, 0, 0, 196), Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.FredokaOne, MaxText = 28 })
	panel.rarityLabel = UI.label(right, "", { Position = UDim2.new(0, 0, 0, 230), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, MaxText = 20 })
	panel.useButton = UI.button(right, "USAR MÁQUINA", UI.Theme.green, function(b)
		if b:GetAttribute("Disabled") then
			return
		end
		MachineController.use()
	end, { Name = "Use", Position = UDim2.new(0, 0, 0, 262), Size = UDim2.new(1, 0, 0, 56), MaxText = 28 })
	panel.skipButton = UI.button(right, "PULAR ⏩", UI.Theme.blue, function()
		MachineController.skip()
	end, { Name = "Skip", Position = UDim2.new(0, 0, 0, 262), Size = UDim2.new(1, 0, 0, 56), Visible = false, MaxText = 28 })
	local actions = UI.make("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 326), Size = UDim2.new(1, 0, 0, 44), Parent = right })
	UI.list(actions, 6, true)
	panel.sellButton = UI.button(actions, "VENDER", UI.Theme.coins, function(b)
		if b:GetAttribute("Disabled") or not state.result then
			return
		end
		MachineController.sellResult()
	end, { Size = UDim2.new(0.34, -4, 1, 0), LayoutOrder = 1, MaxText = 18 })
	panel.favButton = UI.button(actions, "☆ FAVORITAR", UI.Theme.blue, function(b)
		if b:GetAttribute("Disabled") or not state.result then
			return
		end
		local id = state.result.itemId
		local r = Net.call("InventoryAction", { action = "favorite", itemId = id, value = not Store.view.favorites[id] })
		if not r.ok then
			UIController.toast(r.message, "warn")
		end
	end, { Size = UDim2.new(0.36, -4, 1, 0), LayoutOrder = 2, MaxText = 18 })
	panel.showButton = UI.button(actions, "🏛️ EXPOR", UI.Theme.accent, function(b)
		if b:GetAttribute("Disabled") or not state.result then
			return
		end
		local r = Net.call("InventoryAction", { action = "display", itemId = state.result.itemId })
		UIController.toast(r.ok and "🏛️ Objeto exposto na sua vitrine da galeria!" or r.message, r.ok and "info" or "warn")
	end, { Size = UDim2.new(0.3, -4, 1, 0), LayoutOrder = 3, MaxText = 18 })
	setResultButtons(false)
	panel.footer = UI.label(content, "", { Position = UDim2.new(0, 0, 1, -28), Size = UDim2.new(1, 0, 0, 26), TextColor3 = UI.Theme.muted, MaxText = 18 })
end

function MachineController.sellResult()
	local itemId = state.result.itemId
	local item = ItemDefinitions.get(itemId)
	local function send(confirm)
		local r = Net.call("InventoryAction", { action = "sell", itemId = itemId, amount = 1, confirm = confirm })
		if r.ok then
			UIController.toast("💰 Vendido: " .. item.name .. " por " .. Format.int(r.coins) .. " Coins", "coins")
		elseif r.needsConfirm then
			UIController.confirm("Vender " .. item.name .. " (" .. RarityConfig.get(item.rarity).name .. ") por 💰" .. Format.int(item.value) .. "?", "Vender", function()
				send(true)
			end)
		else
			UIController.toast(r.message, "warn")
		end
	end
	send(false)
end

---------------------------------------------------------------------------
-- painel "Máquinas" (lista)
---------------------------------------------------------------------------
local listRows = {}

local function buildMachinesPanel(content)
	UI.label(content, "Escolha uma máquina. Chegue perto dela e aperte E (ou toque) para usar.", { Size = UDim2.new(1, 0, 0, 24), TextColor3 = UI.Theme.muted, MaxText = 18 })
	local holder = UI.make("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 32), Size = UDim2.new(1, 0, 1, -32), Parent = content })
	UI.list(holder, 8)
	for i, def in ipairs(MachineDefinitions.List) do
		local row = UI.frame(holder, { Name = def.id, Size = UDim2.new(1, 0, 0, 90), LayoutOrder = i })
		UI.frame(row, { Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(0, 74, 1, -16), BackgroundColor3 = def.bodyColor })
		UI.label(row, def.name, { Position = UDim2.new(0, 96, 0, 8), Size = UDim2.new(0.45, 0, 0, 30), Font = Enum.Font.FredokaOne, MaxText = 26 })
		local info = UI.label(row, "", { Position = UDim2.new(0, 96, 0, 44), Size = UDim2.new(0.45, 0, 0, 36), TextColor3 = UI.Theme.muted, TextWrapped = true, MaxText = 16 })
		UI.button(row, "VER CHANCES", UI.Theme.blue, function()
			UIController.open("Machine", { machineId = def.id })
		end, { Position = UDim2.new(1, -330, 0.5, -24), Size = UDim2.new(0, 160, 0, 48), MaxText = 18 })
		UI.button(row, "IR ATÉ ➜", UI.Theme.accent, function()
			local r = Net.call("ProgressAction", { action = "goto", target = def.id })
			if r.ok then
				UIController.close()
			else
				UIController.toast(r.message, "warn")
			end
		end, { Position = UDim2.new(1, -160, 0.5, -24), Size = UDim2.new(0, 150, 0, 48), MaxText = 18 })
		listRows[def.id] = info
	end
end

local function refreshMachinesPanel(view)
	for _, def in ipairs(MachineDefinitions.List) do
		local have = 0
		for _, entry in ipairs(def.pool) do
			if view.discovered[entry.item] then
				have = have + 1
			end
		end
		local status = view.level >= def.level and "🔓 Liberada" or ("🔒 Nível " .. def.level)
		listRows[def.id].Text = "💰 " .. Format.int(def.price) .. " Coins   •   " .. status .. "   •   Coleção " .. have .. "/" .. #def.pool
	end
end

---------------------------------------------------------------------------
function MachineController.init()
	UIController.register("Machines", {
		screen = "MachineUI",
		title = "🎰 Máquinas",
		build = buildMachinesPanel,
		refresh = refreshMachinesPanel,
	})
	UIController.register("Machine", {
		screen = "MachineUI",
		title = "Máquina",
		build = buildMachinePanel,
		onOpen = function(args)
			if args.machineId and MachineDefinitions.get(args.machineId) and args.machineId ~= selected then
				selected = args.machineId
				if state.phase ~= "rolling" then
					state = { phase = "idle" }
				end
			end
			if state.phase == "idle" then
				setResultButtons(false)
				panel.status.Text = "Pronto para jogar!"
				panel.rarityLabel.Text = ""
				showItem(nil)
			end
			buildOddsList(selected)
		end,
		refresh = refreshMachinePanel,
		onClose = function()
			if state.phase == "result" then
				state = { phase = "idle" }
			end
		end,
	})

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local machineId = prompt:GetAttribute("MachineId")
		local panelName = prompt:GetAttribute("Panel")
		if machineId then
			UIController.open("Machine", { machineId = machineId })
		elseif panelName then
			UIController.open(panelName)
		end
	end)

	Net.on("MachineResult", function(data)
		if type(data) ~= "table" or data.userId == localPlayer.UserId then
			return -- quem usou já anima pelo próprio pedido
		end
		if MachineDefinitions.get(data.machineId) and ItemDefinitions.get(data.itemId) then
			MachineController.animateMachine(data.machineId, math.min(data.duration or 3, 5), data.itemId, data.rarity)
		end
	end)
end

MachineController.state = function()
	return state
end

return MachineController
