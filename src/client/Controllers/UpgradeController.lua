-- Loja de melhorias: nível atual, benefício (atual → próximo), preço e limite máximo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(Shared.UpgradeConfig)
local Format = require(Shared.Util.Format)

local UI = require(script.Parent.Parent.Util.UI)
local Net = require(script.Parent.Parent.Util.Net)
local UIController = require(script.Parent.UIController)

local UpgradeController = {}

local rows = {}

function UpgradeController.refresh(view)
	for id, row in pairs(rows) do
		local level = view.upgrades[id]
		local max = UpgradeConfig.max(id)
		row.level.Text = "Nível " .. level .. "/" .. max
		if level >= max then
			row.benefit.Text = UpgradeConfig.benefitText(id, level) .. "  (máximo)"
			row.buy.Text = "MÁXIMO"
			UI.setEnabled(row.buy, false)
		else
			local price = UpgradeConfig.price(id, level)
			row.benefit.Text = UpgradeConfig.benefitText(id, level) .. "  →  " .. UpgradeConfig.benefitText(id, level + 1)
			row.buy.Text = "COMPRAR 💰" .. Format.short(price)
			UI.setEnabled(row.buy, view.coins >= price, UI.Theme.green)
		end
	end
end

local function build(content)
	UI.label(content, "Melhorias permanentes. Nenhuma delas muda as chances das máquinas.", { Size = UDim2.new(1, 0, 0, 22), TextColor3 = UI.Theme.muted, MaxText = 17 })
	local holder = UI.make("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 1, -30), Parent = content })
	UI.list(holder, 8)
	for i, id in ipairs(UpgradeConfig.Order) do
		local def = UpgradeConfig.Upgrades[id]
		local row = { }
		local f = UI.frame(holder, { Name = id, Size = UDim2.new(1, 0, 0, 92), LayoutOrder = i })
		UI.label(f, def.icon, { Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(0, 70, 0, 70), TextXAlignment = Enum.TextXAlignment.Center, MaxText = 48 })
		UI.label(f, def.name, { Position = UDim2.new(0, 90, 0, 8), Size = UDim2.new(0.5, 0, 0, 28), Font = Enum.Font.FredokaOne, MaxText = 24 })
		UI.label(f, def.description, { Position = UDim2.new(0, 90, 0, 36), Size = UDim2.new(0.5, 0, 0, 20), TextColor3 = UI.Theme.muted, MaxText = 15 })
		row.benefit = UI.label(f, "", { Position = UDim2.new(0, 90, 0, 60), Size = UDim2.new(0.5, 0, 0, 22), TextColor3 = UI.Theme.xp, MaxText = 17 })
		row.level = UI.label(f, "", { Position = UDim2.new(1, -330, 0, 0), Size = UDim2.new(0, 120, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, MaxText = 20 })
		row.buy = UI.button(f, "COMPRAR", UI.Theme.green, function(b)
			if b:GetAttribute("Disabled") then
				return
			end
			local r = Net.call("UpgradeAction", { action = "buy", upgradeId = id })
			if r.ok then
				UIController.toast("⚙️ " .. def.name .. " agora no nível " .. r.level .. "!", "level")
			else
				UIController.toast(r.message, "warn")
			end
		end, { Name = "Buy", Position = UDim2.new(1, -200, 0.5, -26), Size = UDim2.new(0, 188, 0, 52), MaxText = 20 })
		rows[id] = row
	end
end

function UpgradeController.init()
	UIController.register("Upgrades", {
		screen = "UpgradeUI",
		title = "⚙️ Melhorias",
		build = build,
		refresh = UpgradeController.refresh,
	})
end

return UpgradeController
