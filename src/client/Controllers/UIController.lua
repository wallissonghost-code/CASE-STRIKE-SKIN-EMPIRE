-- UIController: tema, componentes reutilizáveis, escala responsiva (PC/celular),
-- gerenciador de painéis (apenas um aberto por vez), avisos e diálogos de confirmação.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local RarityConfig = require(Shared.Config.RarityConfig)
local SkinModelFactory = require(Shared.Visual.SkinModelFactory)
local CaseModelFactory = require(Shared.Visual.CaseModelFactory)

local UI = {}

local player = Players.LocalPlayer

UI.Theme = {
	bg = Color3.fromRGB(16, 18, 28),
	panel = Color3.fromRGB(24, 27, 42),
	panel2 = Color3.fromRGB(34, 38, 58),
	stroke = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(245, 246, 250),
	muted = Color3.fromRGB(165, 170, 190),
	accent = Color3.fromRGB(255, 176, 46),
	good = Color3.fromRGB(70, 205, 110),
	bad = Color3.fromRGB(235, 70, 80),
	blue = Color3.fromRGB(70, 140, 255),
	purple = Color3.fromRGB(160, 90, 245),
	locked = Color3.fromRGB(90, 92, 105),
}
UI.Fonts = {
	title = Enum.Font.FredokaOne,
	body = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
}
UI.DesignSize = Vector2.new(1280, 720)

---------------------------------------------------------------------------
-- construção básica
---------------------------------------------------------------------------

function UI.make(className, props, children)
	local inst = Instance.new(className)
	local parent = nil
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.corner(inst, radius)
	UI.make("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = inst })
	return inst
end

function UI.stroke(inst, color, thickness, transparency)
	UI.make("UIStroke", {
		Color = color or UI.Theme.stroke,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.82,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
	return inst
end

function UI.padding(inst, px)
	UI.make("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = inst,
	})
	return inst
end

function UI.list(inst, padding, horizontal, align)
	UI.make("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Parent = inst,
	})
	return inst
end

function UI.frame(props)
	props = props or {}
	if props.BackgroundColor3 == nil then
		props.BackgroundColor3 = UI.Theme.panel2
	end
	if props.BorderSizePixel == nil then
		props.BorderSizePixel = 0
	end
	local f = UI.make("Frame", props)
	return f
end

function UI.text(props)
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = UI.Theme.text,
		Font = UI.Fonts.body,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		RichText = true,
	}
	for k, v in pairs(defaults) do
		if props[k] == nil then
			props[k] = v
		end
	end
	return UI.make("TextLabel", props)
end

-- botão com cor, cantos e efeito de toque; props.onClick
function UI.button(props)
	local onClick = props.onClick
	props.onClick = nil
	local color = props.color or UI.Theme.accent
	props.color = nil
	local defaults = {
		BackgroundColor3 = color,
		AutoButtonColor = true,
		TextColor3 = Color3.new(1, 1, 1),
		Font = UI.Fonts.bold,
		TextSize = 16,
		TextWrapped = true,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(140, 40),
	}
	for k, v in pairs(defaults) do
		if props[k] == nil then
			props[k] = v
		end
	end
	local b = UI.make("TextButton", props)
	UI.corner(b, 10)
	UI.make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = b })
	if onClick then
		b.Activated:Connect(function()
			if b:GetAttribute("Disabled") then
				return
			end
			onClick(b)
		end)
	end
	return b
end

function UI.setEnabled(button, enabled, color)
	button:SetAttribute("Disabled", not enabled)
	button.AutoButtonColor = enabled
	if color then
		button.BackgroundColor3 = enabled and color or UI.Theme.locked
	end
	button.TextTransparency = enabled and 0 or 0.35
end

function UI.scroll(props)
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UI.Theme.muted,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}
	for k, v in pairs(defaults) do
		if props[k] == nil then
			props[k] = v
		end
	end
	return UI.make("ScrollingFrame", props)
end

function UI.clear(container)
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

function UI.rarityColor(rarityId)
	local r = RarityConfig.Rarities[rarityId]
	if not r then
		return UI.Theme.muted
	end
	return Color3.fromRGB(r.color[1], r.color[2], r.color[3])
end

function UI.rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

---------------------------------------------------------------------------
-- prévias 3D (ViewportFrame)
---------------------------------------------------------------------------

local spinning = {} -- [viewport] = { model, speed, wobble, t }

local function fitCamera(viewport, model, zoom)
	local cam = viewport.CurrentCamera or Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = viewport
	viewport.CurrentCamera = cam
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * (zoom or 1.05)
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, radius * 0.15, dist), cf.Position)
end

local function isShown(gui)
	local g = gui
	while g and g:IsA("GuiObject") do
		if not g.Visible then
			return false
		end
		g = g.Parent
	end
	return g ~= nil
end

-- Mostra um modelo em um ViewportFrame. opts = { spin = bool, inspect = bool (animação especial), zoom }
function UI.viewport(model, size, opts)
	opts = opts or {}
	local vp = UI.make("ViewportFrame", {
		Size = size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 185),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1.2, -1),
	})
	model:PivotTo(CFrame.new(0, 0, 0) * (opts.baseRotation or CFrame.Angles(0, 0, 0)))
	model.Parent = vp
	fitCamera(vp, model, opts.zoom)
	if opts.spin then
		spinning[vp] = { model = model, speed = opts.inspect and 1.4 or 0.6, wobble = opts.inspect, t = 0, base = model:GetPivot() }
		vp.Destroying:Connect(function()
			spinning[vp] = nil
		end)
	end
	return vp
end

function UI.skinViewport(def, upgrades, size, opts)
	local model = SkinModelFactory.build(def, upgrades)
	return UI.viewport(model, size, opts)
end

function UI.caseViewport(caseDef, size, opts)
	opts = opts or {}
	opts.baseRotation = CFrame.Angles(math.rad(-12), math.rad(25), 0)
	local model = CaseModelFactory.build(caseDef)
	return UI.viewport(model, size, opts)
end

RunService.RenderStepped:Connect(function(dt)
	for vp, s in pairs(spinning) do
		if vp.Parent and isShown(vp) then
			s.t = s.t + dt
			local rot = CFrame.Angles(0, s.t * s.speed, 0)
			if s.wobble then
				rot = rot * CFrame.Angles(math.sin(s.t * 2.2) * 0.25, 0, math.sin(s.t * 1.3) * 0.15)
			end
			s.model:PivotTo(s.base * rot)
		elseif not vp.Parent then
			spinning[vp] = nil
		end
	end
end)

---------------------------------------------------------------------------
-- raiz, escala e camadas
---------------------------------------------------------------------------

local screen, root, uiScale
UI.layers = {}

local function updateScale()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local s = math.min(vs.X / UI.DesignSize.X, vs.Y / UI.DesignSize.Y)
	s = math.clamp(s, 0.42, 1.35)
	uiScale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
	UI.scale = s
	UI.isCompact = vs.X < 900 or vs.Y < 500
end

function UI.init()
	screen = UI.make("ScreenGui", {
		Name = "CaseStrikeUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	root = UI.make("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = screen })
	uiScale = UI.make("UIScale", { Parent = root })
	updateScale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

	for i, name in ipairs({ "HUD", "Panels", "Overlay", "Modal", "Toast" }) do
		UI.layers[name] = UI.make("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = i * 10,
			Parent = root,
		})
	end
	UI.root = root
	UI.screen = screen
end

---------------------------------------------------------------------------
-- painéis
---------------------------------------------------------------------------

local panels = {} -- [name] = { build = fn, instance = table }
UI.current = nil
UI.panelChanged = nil -- definido em init de controladores

-- cria a moldura padrão de painel
function UI.createPanel(title, width, height)
	local frame = UI.frame({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width or 820, height or 540),
		BackgroundColor3 = UI.Theme.panel,
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = UI.layers.Panels,
	})
	UI.corner(frame, 16)
	UI.stroke(frame, UI.Theme.stroke, 2, 0.8)
	local header = UI.frame({ Name = "Header", Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = frame })
	local titleLabel = UI.text({
		Name = "Title",
		Text = title,
		Font = UI.Fonts.title,
		TextSize = 26,
		Size = UDim2.new(1, -120, 1, 0),
		Position = UDim2.fromOffset(20, 0),
		Parent = header,
	})
	UI.button({
		Name = "Close",
		Text = "✕",
		TextSize = 20,
		color = UI.Theme.bad,
		Size = UDim2.fromOffset(40, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Parent = header,
		onClick = function()
			UI.close()
		end,
	})
	local content = UI.frame({
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 56),
		Size = UDim2.new(1, -32, 1, -70),
		Parent = frame,
	})
	return { frame = frame, content = content, title = titleLabel }
end

-- registra um painel. build() -> { frame, refresh(view), onOpen(args), onClose() }
function UI.register(name, build)
	panels[name] = { build = build }
end

function UI.get(name)
	local p = panels[name]
	if not p then
		return nil
	end
	if not p.instance then
		p.instance = p.build()
	end
	return p.instance
end

function UI.open(name, args)
	local inst = UI.get(name)
	if not inst then
		return
	end
	if UI.current and UI.current ~= name then
		UI.close()
	end
	UI.current = name
	inst.frame.Visible = true
	inst.frame.Size = inst.frame.Size -- força layout
	local scale = inst.frame:FindFirstChild("PopScale") or UI.make("UIScale", { Name = "PopScale", Parent = inst.frame })
	scale.Scale = 0.92
	TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if inst.onOpen then
		inst.onOpen(args)
	end
	if inst.refresh and UI.store and UI.store.view then
		inst.refresh(UI.store.view)
	end
end

function UI.close()
	if not UI.current then
		return
	end
	local inst = panels[UI.current] and panels[UI.current].instance
	UI.current = nil
	if inst then
		inst.frame.Visible = false
		if inst.onClose then
			inst.onClose()
		end
	end
end

function UI.toggle(name, args)
	if UI.current == name then
		UI.close()
	else
		UI.open(name, args)
	end
end

function UI.isOpen(name)
	return UI.current == name
end

-- atualiza o painel aberto quando chega uma nova fotografia
function UI.refreshCurrent(view)
	if not UI.current then
		return
	end
	local inst = panels[UI.current].instance
	if inst and inst.refresh then
		inst.refresh(view)
	end
end

---------------------------------------------------------------------------
-- avisos e diálogos
---------------------------------------------------------------------------

local toastList
function UI.toast(message, kind)
	if not toastList then
		toastList = UI.frame({
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 70),
			Size = UDim2.fromOffset(520, 300),
			Parent = UI.layers.Toast,
		})
		UI.list(toastList, 6, false, Enum.HorizontalAlignment.Center)
	end
	local color = UI.Theme.panel2
	if kind == "error" then
		color = UI.Theme.bad
	elseif kind == "good" then
		color = UI.Theme.good
	elseif kind == "rare" then
		color = UI.Theme.purple
	end
	local t = UI.text({
		Text = message,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = UI.Fonts.bold,
		TextSize = 17,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(500, 0),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = color,
		Parent = toastList,
	})
	UI.corner(t, 10)
	UI.padding(t, 10)
	task.delay(3.2, function()
		TweenService:Create(t, TweenInfo.new(0.3), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.wait(0.32)
		t:Destroy()
	end)
end

-- Resposta padrão de uma chamada ao servidor: mostra o erro (se houver) e retorna ok.
function UI.handle(response, successMessage)
	if response.ok then
		if successMessage then
			UI.toast(successMessage, "good")
		end
		return true
	end
	if response.error ~= "busy" then
		UI.toast(response.message or "Não foi possível concluir.", "error")
	end
	return false
end

-- opts = { title, message, confirmText, cancelText, danger, phrase (texto que precisa ser digitado), onConfirm }
function UI.confirm(opts)
	local shade = UI.make("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Parent = UI.layers.Modal,
	})
	local box = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(500, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Theme.panel,
		Parent = shade,
	})
	UI.corner(box, 14)
	UI.stroke(box, opts.danger and UI.Theme.bad or UI.Theme.stroke, 2, opts.danger and 0.2 or 0.8)
	UI.padding(box, 18)
	UI.list(box, 12)
	UI.text({ Text = opts.title or "Confirmar", Font = UI.Fonts.title, TextSize = 24, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1, Parent = box })
	UI.text({ Text = opts.message or "", TextSize = 16, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextColor3 = UI.Theme.muted, LayoutOrder = 2, Parent = box })
	local input
	if opts.phrase then
		input = UI.make("TextBox", {
			PlaceholderText = "Digite " .. opts.phrase,
			Text = "",
			ClearTextOnFocus = false,
			Font = UI.Fonts.bold,
			TextSize = 18,
			TextColor3 = UI.Theme.text,
			BackgroundColor3 = UI.Theme.panel2,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 3,
			Parent = box,
		})
		UI.corner(input, 8)
	end
	local row = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 4, Parent = box })
	UI.list(row, 10, true, Enum.HorizontalAlignment.Right)
	local function closeDialog()
		shade:Destroy()
	end
	UI.button({
		Text = opts.cancelText or "Cancelar",
		color = UI.Theme.panel2,
		Size = UDim2.fromOffset(150, 42),
		Parent = row,
		onClick = closeDialog,
	})
	local okBtn = UI.button({
		Text = opts.confirmText or "Confirmar",
		color = opts.danger and UI.Theme.bad or UI.Theme.good,
		Size = UDim2.fromOffset(180, 42),
		Parent = row,
		onClick = function()
			if opts.phrase and input.Text ~= opts.phrase then
				UI.toast("Digite exatamente: " .. opts.phrase, "error")
				return
			end
			closeDialog()
			if opts.onConfirm then
				task.spawn(opts.onConfirm, input and input.Text or nil)
			end
		end,
	})
	if opts.phrase then
		UI.setEnabled(okBtn, false, opts.danger and UI.Theme.bad or UI.Theme.good)
		input:GetPropertyChangedSignal("Text"):Connect(function()
			UI.setEnabled(okBtn, input.Text == opts.phrase, opts.danger and UI.Theme.bad or UI.Theme.good)
		end)
	end
	return shade
end

-- resumo de recompensa em texto
function UI.rewardText(reward, Format, CaseDefinitions, EconomyConfig)
	local parts = {}
	if reward.credits and reward.credits > 0 then
		table.insert(parts, "₵ " .. Format.short(reward.credits))
	end
	if reward.xp and reward.xp > 0 then
		table.insert(parts, reward.xp .. " XP")
	end
	for k, v in pairs(reward.materials or {}) do
		local m = EconomyConfig.Materials[k]
		table.insert(parts, v .. " " .. (m and m.displayName or k))
	end
	for caseId, n in pairs(reward.freeCases or {}) do
		local c = CaseDefinitions.ById[caseId]
		table.insert(parts, n .. "× " .. (c and c.name or caseId) .. " grátis")
	end
	if reward.luck then
		table.insert(parts, "bônus de sorte")
	end
	if reward.title then
		table.insert(parts, "título")
	end
	return table.concat(parts, " · ")
end

return UI
