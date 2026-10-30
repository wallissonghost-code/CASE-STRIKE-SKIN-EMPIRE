-- Rankings: abas por categoria, com o top do servidor atual e o top global (cache do servidor,
-- atualizado periodicamente; o cliente nunca consulta o DataStore).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)

local UI = require(script.Parent.Parent.Util.UI)
local Store = require(script.Parent.Parent.Util.Store)
local Net = require(script.Parent.Parent.Util.Net)
local UIController = require(script.Parent.UIController)

local LeaderboardController = {}

LeaderboardController.Boards = {
	{ id = "value", label = "💎 Valor", width = 170 },
	{ id = "discovered", label = "📖 Descobertas", width = 190 },
	{ id = "level", label = "⭐ Nível", width = 150 },
	{ id = "achievements", label = "🏅 Conquistas", width = 190 },
}

local board = "value"
local columns = {}

local function fill(column, rows)
	for i, line in ipairs(column.lines) do
		local row = rows and rows[i]
		line.Text = row and (i .. ". " .. row.name .. "   " .. Format.int(row.value)) or (i == 1 and "Sem dados ainda" or "")
		line.TextColor3 = (i == 1 and row) and UI.Theme.coins or UI.Theme.text
	end
end

function LeaderboardController.refresh()
	local data = Store.leaderboard
	if not columns.server then
		return
	end
	fill(columns.server, data and data.server and data.server[board])
	fill(columns.global, data and data.global and data.global[board])
end

local function column(parent, title, x)
	local f = UI.frame(parent, { Position = UDim2.new(x, x > 0 and 6 or 0, 0, 46), Size = UDim2.new(0.5, -6, 1, -46), BackgroundColor3 = UI.Theme.bg })
	UI.label(f, title, { Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -24, 0, 30), Font = Enum.Font.FredokaOne, MaxText = 22 })
	local lines = {}
	for i = 1, 10 do
		lines[i] = UI.label(f, "", { Position = UDim2.new(0, 14, 0, 38 + (i - 1) * 33), Size = UDim2.new(1, -28, 0, 30), MaxText = 18 })
	end
	return { frame = f, lines = lines }
end

local function build(content)
	UI.tabs(content, LeaderboardController.Boards, function(id)
		board = id
		LeaderboardController.refresh()
	end)
	columns.server = column(content, "🏠 Neste servidor", 0)
	columns.global = column(content, "🌍 Global (top 10)", 0.5)
end

function LeaderboardController.init()
	UIController.register("Ranking", {
		screen = "RankingUI",
		title = "🏆 Rankings",
		build = build,
		refresh = LeaderboardController.refresh,
		onOpen = function()
			if not Store.leaderboard then
				task.spawn(function()
					local r = Net.call("ProgressAction", { action = "leaderboard" })
					if r.ok then
						Store.setLeaderboard(r.data)
					end
				end)
			end
		end,
	})
	Net.on("LeaderboardUpdated", function(data)
		if type(data) == "table" then
			Store.setLeaderboard(data)
		end
	end)
	Store.leaderboardChanged:Connect(function()
		if UIController.current == "Ranking" then
			LeaderboardController.refresh()
		end
	end)
end

return LeaderboardController
