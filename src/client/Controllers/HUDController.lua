-- HUD compacto: Coins, nível e barra de XP no topo; menu lateral com os 7 atalhos.
-- Os botões do menu mostram "!" quando há recompensa para resgatar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)

local UI = require(script.Parent.Parent.Util.UI)
local Store = require(script.Parent.Parent.Util.Store)
local Net = require(script.Parent.Parent.Util.Net)
local Sounds = require(script.Parent.Parent.Util.Sounds)
local UIController = require(script.Parent.UIController)

local HUDController = {}

HUDController.Menu = {
	{ panel = "Machines", icon = "🎰", label = "Máquinas" },
	{ panel = "Inventory", icon = "🎒", label = "Inventário" },
	{ panel = "Collection", icon = "📖", label = "Coleção" },
	{ panel = "Upgrades", icon = "⚙️", label = "Melhorias" },
	{ panel = "Missions", icon = "📜", label = "Missões" },
	{ panel = "Ranking", icon = "🏆", label = "Ranking" },
	{ panel = "Settings", icon = "🔧", label = "Config." },
}

local coinsLabel, levelLabel, setXp, itemsLabel
local badges = {}
local lastCoins

local function hasClaimable(list)
	for _, m in ipairs(list or {}) do
		if not m.claimed and (m.progress or m.have) >= (m.target or m.total) then
			return true
		end
	end
	return false
end

function HUDController.refresh(view)
	if not coinsLabel or not view then
		return
	end
	coinsLabel.Text = "💰 " .. Format.int(view.coins)
	levelLabel.Text = "Nv " .. view.level
	if view.xpNeeded > 0 then
		setXp(view.xpInto / view.xpNeeded, Format.int(view.xpInto) .. " / " .. Format.int(view.xpNeeded) .. " XP")
	else
		setXp(1, "Nível máximo")
	end
	itemsLabel.Text = "🎒 " .. view.itemCount .. "/" .. view.capacity .. "   📖 " .. view.discoveredCount .. "/" .. view.totalItems
	badges.Missions.Visible = hasClaimable(view.daily) or hasClaimable(view.achievements) or (view.gift and view.gift.canClaim)
	badges.Collection.Visible = hasClaimable(view.sets)
	if lastCoins and view.coins > lastCoins then
		Sounds.play("coins")
	end
	lastCoins = view.coins
end

function HUDController.init()
	local gui = UIController.screen("MainHUD", 1)

	-- topo: Coins | nível + XP
	local top = UI.frame(gui, {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 560, 0, 52),
		BackgroundColor3 = UI.Theme.panel,
		BackgroundTransparency = 0.1,
		radius = 14,
	})
	UI.stroke(top, Color3.fromRGB(0, 0, 0), 2)
	local coinPill = UI.frame(top, { Position = UDim2.new(0, 8, 0, 6), Size = UDim2.new(0, 170, 1, -12), BackgroundColor3 = Color3.fromRGB(70, 55, 20) })
	coinsLabel = UI.label(coinPill, "💰 0", { Name = "Coins", Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -20, 1, 0), TextColor3 = UI.Theme.coins, Font = Enum.Font.FredokaOne, MaxText = 28 })
	local badge = UI.frame(top, { Position = UDim2.new(0, 186, 0, 6), Size = UDim2.new(0, 64, 1, -12), BackgroundColor3 = UI.Theme.blue })
	levelLabel = UI.label(badge, "Nv 1", { Name = "Level", Size = UDim2.new(1, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.FredokaOne, MaxText = 26 })
	local _, set = UI.progress(top, { Name = "XpBar", Position = UDim2.new(0, 258, 0, 8), Size = UDim2.new(1, -266, 0, 20) }, UI.Theme.xp)
	setXp = set
	itemsLabel = UI.label(top, "", { Name = "Items", Position = UDim2.new(0, 258, 0, 30), Size = UDim2.new(1, -266, 0, 16), TextColor3 = UI.Theme.muted, MaxText = 14 })

	-- menu lateral
	local menu = UI.make("Frame", {
		Name = "SideMenu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 20),
		Size = UDim2.new(0, 96, 0, 7 * 66),
		Parent = gui,
	})
	UI.list(menu, 6)
	for i, entry in ipairs(HUDController.Menu) do
		local b = UI.button(menu, entry.icon .. "\n" .. entry.label, UI.Theme.panel, function()
			UIController.toggle(entry.panel)
		end, { Name = entry.panel, Size = UDim2.new(1, 0, 0, 60), LayoutOrder = i, MaxText = 16 })
		local dot = UI.frame(b, { Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 6), Size = UDim2.new(0, 22, 0, 22), BackgroundColor3 = UI.Theme.red, Visible = false, radius = 11 })
		UI.label(dot, "!", { Size = UDim2.new(1, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, MaxText = 16 })
		badges[entry.panel] = dot
	end

	Store.changed:Connect(HUDController.refresh)
	Net.on("Notify", function(data)
		if type(data) == "table" and type(data.text) == "string" then
			UIController.toast(data.text, data.kind)
			if data.kind == "legendary" or data.kind == "secret" then
				Sounds.play("legendary")
			end
		end
	end)
	if Store.view then
		HUDController.refresh(Store.view)
	end
end

return HUDController
