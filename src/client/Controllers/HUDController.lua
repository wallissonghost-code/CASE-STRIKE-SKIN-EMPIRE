-- HUDController: moedas, renda, evento atual, sorte, poções ativas, menu lateral,
-- estado do escudo e botões rápidos (COLETAR / TRAVAR BASE) e a faixa de quem está carregando.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)

local UI = require(script.Parent.UIController)
local Net = require(script.Parent.Parent.Util.Net)
local Store = require(script.Parent.Parent.Util.Store)

local HUD = {}

local refs = {}

local MENU = {
	{ panel = "Eggs", icon = "🥚", label = "OVOS" },
	{ panel = "Base", icon = "🏠", label = "BASE" },
	{ panel = "Index", icon = "📖", label = "ÍNDICE" },
	{ panel = "Missions", icon = "🎯", label = "MISSÕES" },
	{ panel = "Gifts", icon = "🎁", label = "PRESENTES" },
	{ panel = "Potions", icon = "🧪", label = "POÇÕES" },
	{ panel = "Rebirth", icon = "♻️", label = "RENASCER" },
	{ panel = "Ranking", icon = "🏆", label = "RANKING" },
	{ panel = "Settings", icon = "⚙️", label = "AJUSTES" },
}

local function chip(parent, props)
	local f = UI.text(props)
	f.BackgroundTransparency = 0.25
	f.BackgroundColor3 = UI.Theme.panel
	f.TextXAlignment = Enum.TextXAlignment.Center
	f.Font = UI.Fonts.bold
	f.Parent = parent
	UI.corner(f, 10)
	return f
end

local function build()
	local root = UI.layers.HUD

	-- moedas
	local money = UI.frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(300, 64), BackgroundColor3 = UI.Theme.panel, BackgroundTransparency = 0.15, Parent = root })
	UI.corner(money, 14)
	UI.stroke(money, UI.Theme.toxic, 2, 0.4)
	refs.coins = UI.text({ Text = "$0", Font = UI.Fonts.title, TextSize = 32, TextColor3 = UI.Theme.accent, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 2), Parent = money })
	refs.rate = UI.text({ Text = "+$0/s", Font = UI.Fonts.bold, TextSize = 16, TextColor3 = UI.Theme.toxic, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 40), Parent = money })

	-- evento
	refs.event = chip(root, { Text = "", TextSize = 17, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 78), Size = UDim2.fromOffset(460, 32) })
	-- faixa de quem está carregando uma criatura
	refs.carry = chip(root, { Text = "", TextSize = 18, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 116), Size = UDim2.fromOffset(560, 40), Visible = false })
	refs.carry.BackgroundColor3 = Color3.fromRGB(150, 40, 200)
	refs.carry.BackgroundTransparency = 0.05

	-- sorte e poções
	local right = UI.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(220, 200), Parent = root })
	UI.list(right, 6, false, Enum.HorizontalAlignment.Right)
	refs.luck = UI.button({ Text = "🍀 Sorte +0%", TextSize = 15, color = UI.Theme.panel, Size = UDim2.fromOffset(200, 34), LayoutOrder = 1, Parent = right, onClick = function()
		UI.open("Potions")
	end })
	refs.potions = UI.text({ Text = "", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromOffset(210, 0), LayoutOrder = 2, Parent = right })

	-- menu lateral
	local side = UI.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(150, 600), Parent = root })
	UI.make("UIGridLayout", { CellSize = UDim2.fromOffset(70, 62), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = side })
	refs.menu = {}
	for i, item in ipairs(MENU) do
		local b = UI.button({
			Name = "Menu_" .. item.panel,
			Text = item.icon .. "\n" .. item.label,
			TextSize = 13,
			color = UI.Theme.panel2,
			LayoutOrder = i,
			Parent = side,
			onClick = function()
				UI.toggle(item.panel)
			end,
		})
		local dot = UI.text({ Text = "!", Font = UI.Fonts.title, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, BackgroundColor3 = UI.Theme.bad, Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -14, 0, -6), Visible = false, Parent = b })
		UI.corner(dot, 10)
		refs.menu[item.panel] = { button = b, dot = dot }
	end

	-- base: escudo e coleta
	local bar = UI.frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(520, 56), BackgroundTransparency = 1, Parent = root })
	UI.list(bar, 10, true, Enum.HorizontalAlignment.Center)
	refs.shield = UI.button({
		Name = "ShieldButton",
		Text = "🛡️ TRAVAR BASE",
		TextSize = 17,
		color = UI.Theme.blue,
		Size = UDim2.fromOffset(240, 52),
		Parent = bar,
		onClick = function()
			local res = Net.call("BaseAction", { action = "shield" })
			UI.handle(res, res.ok and ("🛡️ Base travada por " .. math.floor(res.data.seconds) .. "s!") or nil)
		end,
	})
	refs.collect = UI.button({
		Name = "CollectButton",
		Text = "💰 COLETAR",
		TextSize = 17,
		color = UI.Theme.good,
		Size = UDim2.fromOffset(240, 52),
		Parent = bar,
		onClick = function()
			local res = Net.call("BaseAction", { action = "collect" })
			UI.handle(res, res.ok and ("💰 +$" .. Format.short(res.data.coins)) or nil)
		end,
	})
end

local function fmtTime(s)
	s = math.max(0, math.floor(s))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function tick()
	local v = Store.view
	if not v then
		return
	end
	local now = Store.serverNow()
	refs.coins.Text = "$" .. Format.short(v.coins)
	refs.rate.Text = "+$" .. Format.short(v.rate * (v.boost or 1)) .. "/s" .. ((v.boost or 1) > 1 and ("  (×" .. string.gsub(tostring(v.boost), "%.", ",") .. ")") or "")
	if v.event and v.event.endsAt > now then
		refs.event.Text = v.event.icon .. " " .. v.event.name .. " • " .. fmtTime(v.event.endsAt - now)
		refs.event.BackgroundColor3 = Color3.fromRGB(60, 130, 50)
	elseif v.nextEvent then
		refs.event.Text = "Próximo: " .. v.nextEvent.icon .. " " .. v.nextEvent.name .. " em " .. fmtTime(v.nextEvent.startsAt - now)
		refs.event.BackgroundColor3 = UI.Theme.panel
	end
	refs.luck.Text = "🍀 Sorte +" .. math.floor((v.luck or 0) * 100 + 0.5) .. "%"
	local buffs = {}
	for _, id in ipairs(GameConfig.PotionOrder) do
		local e = v.activePotions and v.activePotions[id] or 0
		if e > now then
			table.insert(buffs, GameConfig.Potions[id].icon .. " " .. fmtTime(e - now))
		end
	end
	refs.potions.Text = table.concat(buffs, "   ")
	-- escudo
	local left = (v.shieldUntil or 0) - now
	if left > 0 then
		refs.shield.Text = "🛡️ TRAVADA " .. math.ceil(left) .. "s"
		UI.setEnabled(refs.shield, false, UI.Theme.blue)
	else
		refs.shield.Text = "🛡️ TRAVAR BASE"
		UI.setEnabled(refs.shield, true, UI.Theme.blue)
	end
	refs.collect.Text = "💰 COLETAR $" .. Format.short(Store.pendingLive())
	-- carregando
	if v.carrying then
		refs.carry.Visible = true
		refs.carry.Text = "🏃 " .. UI.creatureName(v.carrying.speciesId, v.carrying.mutationId) .. " — corra para a SUA base! " .. math.max(0, math.ceil(v.carrying.endsAt - now)) .. "s"
	else
		refs.carry.Visible = false
	end
	-- avisos no menu
	local missionsReady = 0
	for _, m in ipairs(v.missions or {}) do
		if not m.claimed and m.progress >= m.target then
			missionsReady = missionsReady + 1
		end
	end
	refs.menu.Missions.dot.Visible = missionsReady > 0
	refs.menu.Gifts.dot.Visible = v.gifts and v.gifts.available or false
	local milestoneReady = false
	for _, m in ipairs(v.milestones or {}) do
		if m.ready and not m.claimed then
			milestoneReady = true
		end
	end
	refs.menu.Index.dot.Visible = milestoneReady
	refs.menu.Rebirth.dot.Visible = v.rebirth and not v.rebirth.maxed and v.coins >= v.rebirth.cost or false
end

function HUD.init()
	build()
	Store.changed:Connect(tick)
	task.spawn(function()
		while true do
			task.wait(0.5)
			tick()
		end
	end)
end

return HUD
