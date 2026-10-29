-- IndexController: índice de criaturas (16 espécies × 6 mutações = 96 combinações)
-- e marcos com recompensa.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)

local UI = require(script.Parent.UIController)
local Net = require(script.Parent.Parent.Util.Net)

local Index = {}

local function build()
	local p = UI.createPanel("📖 Índice de mutantes", 920, 590, "IndexBook")
	local header = UI.text({ Text = "", TextSize = 15, Size = UDim2.new(1, 0, 0, 24), Parent = p.content })
	local milestones = UI.scroll({ Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 58), ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, Parent = p.content })
	UI.list(milestones, 8, true)
	local grid = UI.scroll({ Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 1, -94), Parent = p.content })
	UI.list(grid, 4)

	local function refresh(view)
		header.Text = "Descobertas: <b>" .. view.indexCount .. "/" .. view.indexTotal .. "</b> combinações. Cada espécie em cada mutação conta uma vez."
		UI.clear(milestones)
		for i, m in ipairs(view.milestones) do
			local b = UI.button({
				Text = m.count .. " descobertas\n" .. (m.claimed and "✔ resgatado" or UI.rewardText(m.rewardCoins, m.rewardPotions)),
				TextSize = 13,
				LayoutOrder = i,
				color = m.claimed and UI.Theme.panel2 or (m.ready and UI.Theme.good or UI.Theme.locked),
				Size = UDim2.fromOffset(150, 52),
				Parent = milestones,
				onClick = function()
					UI.handle(Net.call("ClaimAction", { action = "milestone", milestoneId = m.id }), "Marco resgatado!")
				end,
			})
			UI.setEnabled(b, m.ready and not m.claimed)
		end
		UI.clear(grid)
		local head = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 22), LayoutOrder = 0, Parent = grid })
		UI.text({ Text = "Espécie", Font = UI.Fonts.bold, TextSize = 13, Size = UDim2.fromOffset(200, 22), Parent = head })
		for j, mid in ipairs(GameConfig.MutationOrder) do
			UI.text({ Text = GameConfig.Mutations[mid].name, Font = UI.Fonts.bold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(100, 22), Position = UDim2.fromOffset(200 + (j - 1) * 106, 0), Parent = head })
		end
		for i, s in ipairs(GameConfig.Species) do
			local row = UI.frame({ Size = UDim2.new(1, -8, 0, 40), LayoutOrder = i, BackgroundTransparency = 0.4, Parent = grid })
			UI.corner(row, 8)
			local anySeen = false
			for _, mid in ipairs(GameConfig.MutationOrder) do
				if view.index[s.id .. ":" .. mid] then
					anySeen = true
				end
			end
			UI.text({ Text = anySeen and UI.creatureName(s.id, "normal", true) or "???", Font = UI.Fonts.bold, TextSize = 15, Size = UDim2.fromOffset(190, 40), Position = UDim2.fromOffset(8, 0), Parent = row })
			for j, mid in ipairs(GameConfig.MutationOrder) do
				local seen = view.index[s.id .. ":" .. mid]
				local cell = UI.frame({ Size = UDim2.fromOffset(100, 32), Position = UDim2.fromOffset(200 + (j - 1) * 106, 4), BackgroundColor3 = seen and UI.rarityColor(s.rarity):Lerp(UI.Theme.panel, 0.35) or UI.Theme.panel, Parent = row })
				UI.corner(cell, 6)
				UI.text({ Text = seen and ("✔ $" .. Format.short(s.income * GameConfig.Mutations[mid].mult) .. "/s") or "—", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = cell })
			end
		end
	end
	return { frame = p.frame, refresh = refresh }
end

function Index.init()
	UI.register("Index", build)
end

return Index
