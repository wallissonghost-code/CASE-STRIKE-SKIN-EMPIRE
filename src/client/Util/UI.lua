-- Construtores de interface com o visual do jogo (cantos arredondados, contorno, cores).
-- Todas as telas são desenhadas numa resolução virtual de 1100×650 e escaladas por UIScale
-- (UIController), então funcionam em PC, celular e tablet.

local UI = {}

local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

UI.Theme = {
	bg = C(26, 22, 46),
	panel = C(36, 31, 64),
	card = C(50, 43, 86),
	cardLight = C(66, 58, 110),
	text = C(255, 255, 255),
	muted = C(185, 180, 215),
	accent = C(255, 90, 165),
	coins = C(255, 205, 60),
	green = C(70, 205, 110),
	blue = C(70, 150, 255),
	red = C(235, 70, 80),
	grey = C(110, 105, 140),
	xp = C(120, 200, 255),
}

-- chaves usadas só por estes construtores (não são propriedades do Roblox)
local HELPER_KEYS = { Parent = true, radius = true, MaxText = true }

function UI.make(class, props, children)
	local inst = Instance.new(class)
	if class == "Frame" or class == "ScrollingFrame" then
		inst.BorderSizePixel = 0
	end
	for k, v in pairs(props or {}) do
		if not HELPER_KEYS[k] then
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function UI.corner(inst, radius)
	UI.make("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = inst })
	return inst
end

function UI.stroke(inst, color, thickness)
	UI.make("UIStroke", { Color = color or C(0, 0, 0), Thickness = thickness or 2, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = inst })
	return inst
end

function UI.frame(parent, props)
	props = props or {}
	props.Parent = parent
	if props.BackgroundColor3 == nil then
		props.BackgroundColor3 = UI.Theme.card
	end
	local f = UI.make("Frame", props)
	UI.corner(f, props.radius or 10)
	return f
end

function UI.label(parent, text, props)
	local p = {
		BackgroundTransparency = 1,
		Text = text or "",
		TextColor3 = UI.Theme.text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	local l = UI.make("TextLabel", p)
	UI.make("UITextSizeConstraint", { MaxTextSize = p.MaxText or 26, MinTextSize = 8, Parent = l })
	return l
end

-- botão com retorno de clique; props.MaxText limita o tamanho do texto
function UI.button(parent, text, color, onClick, props)
	local p = {
		Text = text,
		BackgroundColor3 = color or UI.Theme.accent,
		TextColor3 = UI.Theme.text,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		AutoButtonColor = true,
		Size = UDim2.new(0, 160, 0, 44),
		Parent = parent,
	}
	for k, v in pairs(props or {}) do
		if k ~= "MaxText" then
			p[k] = v
		end
	end
	local b = UI.make("TextButton", p)
	UI.corner(b, 10)
	UI.stroke(b, C(0, 0, 0), 2)
	UI.make("UITextSizeConstraint", { MaxTextSize = (props and props.MaxText) or 24, MinTextSize = 8, Parent = b })
	UI.make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = b })
	if onClick then
		b.Activated:Connect(function()
			onClick(b)
		end)
	end
	return b
end

function UI.setEnabled(button, enabled, color)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = enabled and (color or UI.Theme.accent) or UI.Theme.grey
	button:SetAttribute("Disabled", not enabled)
end

-- barra de progresso; retorna o frame e a função set(fração, texto)
function UI.progress(parent, props, fillColor)
	local bar = UI.frame(parent, props)
	bar.BackgroundColor3 = UI.Theme.bg
	local fill = UI.frame(bar, { BackgroundColor3 = fillColor or UI.Theme.green, Size = UDim2.new(0, 0, 1, 0) })
	local text = UI.label(bar, "", { Size = UDim2.new(1, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, MaxText = 18 })
	local function set(frac, label)
		frac = math.clamp(frac or 0, 0, 1)
		fill.Size = UDim2.new(frac, 0, 1, 0)
		fill.Visible = frac > 0
		text.Text = label or ""
	end
	return bar, set
end

function UI.list(parent, padding, horizontal)
	return UI.make("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function UI.scroll(parent, props)
	local p = {
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return UI.make("ScrollingFrame", p)
end

function UI.viewport(parent, props)
	local p = { BackgroundColor3 = UI.Theme.bg, Parent = parent }
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Ambient = C(200, 200, 210)
	p.LightColor = C(255, 255, 255)
	local v = UI.make("ViewportFrame", p)
	UI.corner(v, 10)
	return v
end

-- abas: retorna a função select(nome) e a tabela de botões
function UI.tabs(parent, names, onSelect, props)
	local holder = UI.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Parent = parent })
	for k, v in pairs(props or {}) do
		holder[k] = v
	end
	UI.list(holder, 6, true)
	local buttons = {}
	local function select(name)
		for n, b in pairs(buttons) do
			b.BackgroundColor3 = (n == name) and UI.Theme.accent or UI.Theme.cardLight
		end
		onSelect(name)
	end
	for i, entry in ipairs(names) do
		local b = UI.button(holder, entry.label, UI.Theme.cardLight, function()
			select(entry.id)
		end, { Size = UDim2.new(0, entry.width or 150, 1, 0), LayoutOrder = i, MaxText = 20 })
		buttons[entry.id] = b
	end
	return select, buttons
end

return UI
