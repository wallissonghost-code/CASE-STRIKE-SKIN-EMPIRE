-- Gerencia as telas (ScreenGui) e as janelas. Regras:
-- * só UMA janela grande aberta por vez (abrir outra fecha a atual);
-- * cada janela é montada só na primeira vez que abre (carregamento sob demanda) e reaproveitada;
-- * tudo é desenhado em 1100×650 virtuais e escalado (UIScale) para o tamanho da tela.

local Players = game:GetService("Players")
local UI = require(script.Parent.Parent.Util.UI)
local Store = require(script.Parent.Parent.Util.Store)
local Sounds = require(script.Parent.Parent.Util.Sounds)

local UIController = {}

UIController.current = nil
UIController.panels = {}
UIController.screens = {}
UIController.scale = 1

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local scales = {}

local VIRTUAL_W, VIRTUAL_H = 1100, 650
local WINDOW_W, WINDOW_H = 780, 500

local function computeScale()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(VIRTUAL_W, VIRTUAL_H)
	return math.clamp(math.min(size.X / VIRTUAL_W, size.Y / VIRTUAL_H), 0.5, 1.3)
end

local function applyScale()
	UIController.scale = computeScale()
	for _, s in ipairs(scales) do
		s.Scale = UIController.scale
	end
end

function UIController.screen(name, displayOrder)
	local gui = UIController.screens[name]
	if gui then
		return gui
	end
	gui = UI.make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 1,
		Parent = playerGui,
	})
	local scale = UI.make("UIScale", { Scale = UIController.scale, Parent = gui })
	table.insert(scales, scale)
	UIController.screens[name] = gui
	return gui
end

-- janela padrão centralizada: retorna janela, área de conteúdo e título
function UIController.window(screenName, title)
	local gui = UIController.screen(screenName, 5)
	local window = UI.frame(gui, {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H),
		BackgroundColor3 = UI.Theme.panel,
		Visible = false,
		radius = 16,
	})
	UI.stroke(window, UI.Theme.accent, 3)
	local titleLabel = UI.label(window, title, {
		Name = "Title",
		Font = Enum.Font.FredokaOne,
		Position = UDim2.new(0, 20, 0, 10),
		Size = UDim2.new(1, -90, 0, 38),
		MaxText = 32,
	})
	UI.button(window, "X", UI.Theme.red, function()
		UIController.close()
	end, { Name = "Close", Position = UDim2.new(1, -56, 0, 10), Size = UDim2.new(0, 44, 0, 40) })
	local content = UI.make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 58),
		Size = UDim2.new(1, -32, 1, -72),
		Parent = window,
	})
	return window, content, titleLabel
end

-- panel = { screen, title, build(content, window, titleLabel), refresh(view), onOpen(args), onClose() }
function UIController.register(name, panel)
	UIController.panels[name] = panel
end

local function ensureBuilt(panel)
	if panel.window then
		return
	end
	local window, content, titleLabel = UIController.window(panel.screen, panel.title)
	panel.window, panel.content, panel.titleLabel = window, content, titleLabel
	panel.build(content, window, titleLabel)
end

function UIController.open(name, args)
	local panel = UIController.panels[name]
	if not panel then
		return
	end
	if UIController.current and UIController.current ~= name then
		UIController.close(true)
	end
	ensureBuilt(panel)
	UIController.current = name
	panel.window.Visible = true
	if panel.onOpen then
		panel.onOpen(args or {})
	end
	if panel.refresh and Store.view then
		panel.refresh(Store.view)
	end
	Sounds.play("click")
end

function UIController.toggle(name, args)
	if UIController.current == name then
		UIController.close()
	else
		UIController.open(name, args)
	end
end

function UIController.close(silent)
	local name = UIController.current
	if not name then
		return
	end
	local panel = UIController.panels[name]
	UIController.current = nil
	if panel.window then
		panel.window.Visible = false
	end
	if panel.onClose then
		panel.onClose()
	end
	if not silent then
		Sounds.play("click")
	end
end

function UIController.refreshCurrent()
	local name = UIController.current
	local panel = name and UIController.panels[name]
	if panel and panel.refresh and Store.view then
		panel.refresh(Store.view)
	end
end

---------------------------------------------------------------------------
-- avisos (toasts) e confirmação
---------------------------------------------------------------------------
local toastHolder
local TOAST_COLORS = {
	info = UI.Theme.card,
	coins = Color3.fromRGB(150, 110, 20),
	warn = Color3.fromRGB(150, 50, 60),
	level = Color3.fromRGB(40, 110, 170),
	legendary = Color3.fromRGB(170, 120, 10),
	secret = Color3.fromRGB(160, 20, 40),
}

function UIController.toast(text, kind)
	if not toastHolder then
		local gui = UIController.screen("Toasts", 20)
		toastHolder = UI.make("Frame", {
			Name = "Holder",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 70),
			Size = UDim2.new(0, 340, 0, 400),
			Parent = gui,
		})
		UI.list(toastHolder, 6)
	end
	local items = {}
	for _, c in ipairs(toastHolder:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(items, c)
		end
	end
	if #items >= 4 then
		items[1]:Destroy()
	end
	local f = UI.frame(toastHolder, { Name = "Toast", Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = TOAST_COLORS[kind] or UI.Theme.card })
	UI.stroke(f, Color3.fromRGB(0, 0, 0), 2)
	UI.label(f, text, { Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -20, 1, -8), TextWrapped = true, MaxText = 18 })
	task.delay(kind == "secret" and 7 or 4, function()
		if f.Parent then
			f:Destroy()
		end
	end)
	return f
end

-- janela pequena de confirmação (não fecha a janela grande atual)
function UIController.confirm(text, yesText, onYes)
	local gui = UIController.screen("Dialogs", 30)
	local old = gui:FindFirstChild("Confirm")
	if old then
		old:Destroy()
	end
	local shade = UI.make("Frame", { Name = "Confirm", BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.new(1, 0, 1, 0), Parent = gui })
	local box = UI.frame(shade, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 420, 0, 200), BackgroundColor3 = UI.Theme.panel })
	UI.stroke(box, UI.Theme.coins, 3)
	UI.label(box, text, { Position = UDim2.new(0, 20, 0, 16), Size = UDim2.new(1, -40, 0, 100), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, MaxText = 22 })
	UI.button(box, "Cancelar", UI.Theme.grey, function()
		shade:Destroy()
	end, { Position = UDim2.new(0, 30, 1, -64), Size = UDim2.new(0, 160, 0, 48) })
	UI.button(box, yesText or "Confirmar", UI.Theme.green, function()
		shade:Destroy()
		onYes()
	end, { Position = UDim2.new(1, -190, 1, -64), Size = UDim2.new(0, 160, 0, 48) })
	return shade
end

function UIController.init()
	applyScale()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
	end
	Store.changed:Connect(function()
		UIController.refreshCurrent()
	end)
end

return UIController
