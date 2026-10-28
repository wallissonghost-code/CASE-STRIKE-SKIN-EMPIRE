-- HUDController: HUD permanente (patrimônio, equipamentos, saldo, nível/XP, nome, evento)
-- e os menus laterais. Atualiza automaticamente a cada nova fotografia do servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local ProgressionConfig = require(Shared.Config.ProgressionConfig)
local FeatureFlags = require(Shared.Config.FeatureFlags)

local UI = require(script.Parent.UIController)
local Store = require(script.Parent.Parent.Util.Store)

local HUD = {}

local refs = {}

local LEFT_MENU = {
	{ id = "Battle", icon = "⚔️", label = "Batalha", locked = true },
	{ id = "Inventory", icon = "🎒", label = "Itens" },
	{ id = "Rebirth", icon = "♻️", label = "Renascer" },
	{ id = "Shop", icon = "🛒", label = "Loja" },
	{ id = "Bank", icon = "🏦", label = "Banco" },
}
local RIGHT_MENU = {
	{ id = "Gifts", icon = "🎁", label = "Presentes" },
	{ id = "Index", icon = "📖", label = "Índice" },
	{ id = "Luck", icon = "🍀", label = "Sorte" },
	{ id = "Missions", icon = "📜", label = "Missões" },
	{ id = "Attributes", icon = "📊", label = "Atributos" },
	{ id = "Upgrade", icon = "🔧", label = "Melhorador" },
}

local function menuButton(parent, entry, order)
	local holder = UI.frame({ BackgroundTransparency = 1, Size = UDim2.fromOffset(78, 82), LayoutOrder = order, Parent = parent })
	local b = UI.button({
		Text = entry.icon,
		TextSize = 30,
		Font = Enum.Font.GothamBold,
		color = entry.locked and UI.Theme.locked or UI.Theme.panel,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.fromOffset(7, 0),
		Parent = holder,
		onClick = function()
			if entry.locked then
				UI.open("Battle")
			else
				UI.toggle(entry.id)
			end
		end,
	})
	UI.stroke(b, UI.Theme.stroke, 2, 0.75)
	UI.text({
		Text = entry.label,
		TextSize = 13,
		Font = UI.Fonts.bold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 64),
		Parent = holder,
	})
	if entry.locked then
		local tag = UI.text({
			Text = FeatureFlags.LockedLabel,
			TextSize = 10,
			Font = UI.Fonts.bold,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = UI.Theme.bad,
			Size = UDim2.fromOffset(62, 16),
			Position = UDim2.fromOffset(8, -6),
			Parent = holder,
		})
		UI.corner(tag, 6)
	end
	local badge = UI.text({
		Name = "Badge",
		Text = "!",
		TextSize = 14,
		Font = UI.Fonts.bold,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0,
		BackgroundColor3 = UI.Theme.bad,
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.fromOffset(56, -4),
		Visible = false,
		Parent = holder,
	})
	UI.corner(badge, 11)
	refs["badge_" .. entry.id] = badge
end

local function statBox(parent, title, color, order)
	local box = UI.frame({ Size = UDim2.fromOffset(200, 54), BackgroundColor3 = UI.Theme.panel, BackgroundTransparency = 0.15, LayoutOrder = order, Parent = parent })
	UI.corner(box, 10)
	UI.stroke(box, color, 2, 0.4)
	UI.text({ Text = title, TextSize = 12, Font = UI.Fonts.bold, TextColor3 = color, Size = UDim2.new(1, -16, 0, 16), Position = UDim2.fromOffset(10, 6), Parent = box })
	local value = UI.text({ Text = "—", TextSize = 21, Font = UI.Fonts.title, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(10, 22), Parent = box })
	return value
end

function HUD.init()
	local layer = UI.layers.HUD

	-- topo esquerdo: nome, título e nível
	local id = UI.frame({ Size = UDim2.fromOffset(300, 64), Position = UDim2.fromOffset(14, 10), BackgroundColor3 = UI.Theme.panel, BackgroundTransparency = 0.2, Parent = layer })
	UI.corner(id, 12)
	local lvl = UI.text({
		Text = "1",
		Font = UI.Fonts.title,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0,
		BackgroundColor3 = UI.Theme.accent,
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.fromOffset(8, 8),
		Parent = id,
	})
	UI.corner(lvl, 24)
	refs.levelBadge = lvl
	refs.name = UI.text({ Text = "...", Font = UI.Fonts.title, TextSize = 20, Size = UDim2.new(1, -70, 0, 24), Position = UDim2.fromOffset(64, 8), TextTruncate = Enum.TextTruncate.AtEnd, Parent = id })
	refs.title = UI.text({ Text = "", TextSize = 13, TextColor3 = UI.Theme.accent, Font = UI.Fonts.bold, Size = UDim2.new(1, -70, 0, 18), Position = UDim2.fromOffset(64, 34), Parent = id })

	-- topo central: evento ou desafio
	local ev = UI.button({
		Text = "",
		color = UI.Theme.purple,
		BackgroundTransparency = 0.1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(420, 52),
		Parent = layer,
		onClick = function()
			UI.open("Missions")
		end,
	})
	refs.eventTitle = UI.text({ Text = "", Font = UI.Fonts.title, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -10, 0, 24), Position = UDim2.fromOffset(5, 4), Parent = ev })
	refs.eventSub = UI.text({ Text = "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(5, 28), Parent = ev })

	-- topo direito: rankings
	UI.button({
		Text = "🏆 Rankings",
		color = UI.Theme.panel,
		BackgroundTransparency = 0.15,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(150, 44),
		Parent = layer,
		onClick = function()
			UI.toggle("Leaderboard")
		end,
	})

	-- menus laterais
	local left = UI.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 10), Size = UDim2.fromOffset(80, 440), Parent = layer })
	UI.list(left, 4)
	for i, e in ipairs(LEFT_MENU) do
		menuButton(left, e, i)
	end
	local right = UI.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 10), Size = UDim2.fromOffset(80, 520), Parent = layer })
	UI.list(right, 2)
	for i, e in ipairs(RIGHT_MENU) do
		menuButton(right, e, i)
	end

	-- inferior esquerdo: economia
	local econ = UI.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.fromOffset(200, 190), Parent = layer })
	UI.list(econ, 6)
	refs.netWorth = statBox(econ, "PATRIMÔNIO LÍQUIDO", UI.Theme.accent, 1)
	refs.equipValue = statBox(econ, "VALOR DOS EQUIPAMENTOS", UI.Theme.purple, 2)
	refs.credits = statBox(econ, "SALDO DISPONÍVEL", UI.Theme.good, 3)

	-- inferior central: barra de XP
	local xpBack = UI.frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(520, 30), BackgroundColor3 = UI.Theme.bg, BackgroundTransparency = 0.25, Parent = layer })
	UI.corner(xpBack, 15)
	UI.stroke(xpBack, UI.Theme.blue, 2, 0.3)
	refs.xpFill = UI.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.Theme.blue, Parent = xpBack })
	UI.corner(refs.xpFill, 15)
	refs.xpText = UI.text({ Text = "", Font = UI.Fonts.bold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = xpBack })

	-- inferior direito: botão principal de caixas
	local caseBtn = UI.button({
		Text = "📦  CAIXAS",
		Font = UI.Fonts.title,
		TextSize = 30,
		color = UI.Theme.accent,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -100, 1, -14),
		Size = UDim2.fromOffset(230, 74),
		Parent = layer,
		onClick = function()
			UI.toggle("Shop")
		end,
	})
	UI.stroke(caseBtn, Color3.new(1, 1, 1), 3, 0.2)
	refs.caseBtn = caseBtn
	task.spawn(function()
		local grad = UI.make("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 205, 80), Color3.fromRGB(255, 120, 40)),
			Rotation = 90,
			Parent = caseBtn,
		})
		while caseBtn.Parent do
			TweenService:Create(grad, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { Rotation = 270 }):Play()
			task.wait(1.2)
			TweenService:Create(grad, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { Rotation = 90 }):Play()
			task.wait(1.2)
		end
	end)

	Store.changed:Connect(HUD.refresh)
	-- relógio do evento (tempo real até o fim, pelo horário do servidor)
	task.spawn(function()
		while true do
			HUD.tick()
			task.wait(1)
		end
	end)
end

function HUD.refresh(view)
	refs.name.Text = view.playerName or ""
	local title = ProgressionConfig.Titles[view.equippedTitle or ""]
	local rb = view.rebirths > 0 and ("  ♻️" .. view.rebirths) or ""
	refs.title.Text = (title and title.displayName or "") .. rb
	refs.levelBadge.Text = tostring(view.level)
	refs.netWorth.Text = "₵ " .. Format.short(view.wealth.netWorth)
	refs.equipValue.Text = "₵ " .. Format.short(view.wealth.equipValue)
	refs.credits.Text = "₵ " .. Format.short(view.credits)
	local frac = view.level >= view.maxLevel and 1 or math.clamp(view.xp / math.max(1, view.xpNeeded), 0, 1)
	TweenService:Create(refs.xpFill, TweenInfo.new(0.35), { Size = UDim2.fromScale(math.max(frac, 0.02), 1) }):Play()
	if view.level >= view.maxLevel then
		refs.xpText.Text = "Nível " .. view.level .. " — MÁXIMO"
	else
		refs.xpText.Text = "Nível " .. view.level .. "  •  " .. Format.int(view.xp) .. " / " .. Format.int(view.xpNeeded) .. " XP"
	end

	-- avisos (!) nos menus
	local giftReady = view.daily.available
	for _, r in ipairs(view.levelRewards) do
		if r.available and not r.claimed then
			giftReady = true
		end
	end
	for _, a in ipairs(view.achievements) do
		if a.unlocked and not a.claimed then
			giftReady = true
		end
	end
	refs.badge_Gifts.Visible = giftReady
	local missionReady = false
	for _, list in ipairs({ view.missions.daily, view.missions.weekly, view.event and view.event.challenges or {} }) do
		for _, m in ipairs(list) do
			if m.progress >= m.target and not m.claimed then
				missionReady = true
			end
		end
	end
	refs.badge_Missions.Visible = missionReady
	local colReady = false
	for _, c in pairs(view.collections) do
		if c.complete and not c.claimed then
			colReady = true
		end
	end
	refs.badge_Index.Visible = colReady
	refs.badge_Bank.Visible = view.bank.pending >= view.bank.storageCap * 0.999 and view.bank.rate > 0
	refs.badge_Rebirth.Visible = view.rebirth.canRebirth
	HUD.tick()
end

function HUD.tick()
	local view = Store.view
	if not view then
		return
	end
	local now = Store.serverNow()
	if view.event then
		refs.eventTitle.Text = "🎉 " .. view.event.name
		refs.eventSub.Text = "Termina em " .. Format.duration(view.event.endsAt - now) .. " • toque para ver os desafios"
	else
		local done, total = 0, 0
		for _, m in ipairs(view.missions.daily) do
			total = total + 1
			if m.progress >= m.target then
				done = done + 1
			end
		end
		refs.eventTitle.Text = "📜 Desafio diário: " .. done .. "/" .. total
		local nextTxt = view.nextEvent and (" • próximo evento em " .. Format.duration(view.nextEvent.startsAt - now)) or ""
		refs.eventSub.Text = "Novas missões em " .. Format.duration(view.daily.secondsUntilReset - (now - view.serverTime)) .. nextTxt
	end
end

return HUD
