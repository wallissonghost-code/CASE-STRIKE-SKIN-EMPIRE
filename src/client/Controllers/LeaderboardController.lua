-- LeaderboardController: rankings globais (cache do servidor, atualizado periodicamente) e do servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)

local UI = require(script.Parent.UIController)
local Net = require(script.Parent.Parent.Util.Net)
local Store = require(script.Parent.Parent.Util.Store)

local Leaderboard = {}

local function formatValue(boardId, v)
	if boardId == "netWorth" then
		return "₵ " .. Format.short(v)
	elseif boardId == "level" then
		local rb = math.floor(v / 1000)
		local lvl = v % 1000
		return (rb > 0 and ("♻️" .. rb .. " • ") or "") .. "Nv " .. lvl
	end
	return Format.int(v)
end

local function build()
	local p = UI.createPanel("🏆 Rankings", 860, 600)
	local state = { board = "netWorth", scope = "global", data = nil }
	local tabs = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Parent = p.content })
	UI.list(tabs, 6, true)
	local scopeRow = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 44), Parent = p.content })
	UI.list(scopeRow, 6, true)
	local note = UI.text({ TextSize = 12, TextColor3 = UI.Theme.muted, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 82), Parent = p.content })
	local list = UI.scroll({ Size = UDim2.new(1, 0, 1, -106), Position = UDim2.fromOffset(0, 104), Parent = p.content })
	UI.list(list, 4)
	local render

	local function fetch()
		task.spawn(function()
			local res = Net.call("LeaderboardRequest", { action = "get" })
			if res.ok then
				state.data = res.data
				render()
			else
				UI.handle(res)
			end
		end)
	end

	render = function()
		UI.clear(tabs)
		UI.clear(scopeRow)
		UI.clear(list)
		local data = state.data
		if not data then
			note.Text = "Carregando..."
			return
		end
		for _, b in ipairs(data.boards) do
			UI.button({
				Text = b.displayName,
				TextSize = 13,
				color = state.board == b.id and UI.Theme.accent or UI.Theme.panel2,
				Size = UDim2.fromOffset(160, 36),
				Parent = tabs,
				onClick = function()
					state.board = b.id
					render()
				end,
			})
		end
		for _, s in ipairs({ { "global", "🌍 Global" }, { "server", "🖥️ Este servidor" } }) do
			UI.button({
				Text = s[2],
				TextSize = 13,
				color = state.scope == s[1] and UI.Theme.blue or UI.Theme.panel2,
				Size = UDim2.fromOffset(150, 32),
				Parent = scopeRow,
				onClick = function()
					state.scope = s[1]
					render()
				end,
			})
		end
		UI.button({ Text = "↻ Atualizar", TextSize = 13, color = UI.Theme.panel2, Size = UDim2.fromOffset(120, 32), Parent = scopeRow, onClick = fetch })

		local rows = {}
		if state.scope == "global" then
			if not data.globalEnabled then
				note.Text = "Rankings globais indisponíveis neste ambiente (DataStore desativado)."
			else
				note.Text = data.updatedAt > 0 and ("Atualizado periodicamente pelo servidor • há " .. Format.duration(Store.serverNow() - data.updatedAt)) or "Os rankings globais aparecem alguns minutos após o servidor iniciar."
			end
			for _, r in ipairs(data.global[state.board] or {}) do
				table.insert(rows, { name = r.name, value = r.value })
			end
		else
			note.Text = "Valores ao vivo dos jogadores deste servidor."
			for _, s in ipairs(data.server) do
				table.insert(rows, { name = s.name, value = s[state.board] or 0 })
			end
			table.sort(rows, function(a, b)
				return a.value > b.value
			end)
		end
		for i, r in ipairs(rows) do
			local f = UI.frame({ BackgroundColor3 = i <= 3 and UI.Theme.panel2:Lerp(UI.Theme.accent, 0.18) or UI.Theme.panel2, Size = UDim2.new(1, -8, 0, 38), LayoutOrder = i, Parent = list })
			UI.corner(f, 8)
			UI.text({ Text = "#" .. i, Font = UI.Fonts.title, TextSize = 18, Size = UDim2.fromOffset(50, 38), Position = UDim2.fromOffset(12, 0), Parent = f })
			UI.text({ Text = tostring(r.name), Font = UI.Fonts.bold, TextSize = 15, Size = UDim2.new(1, -280, 1, 0), Position = UDim2.fromOffset(66, 0), Parent = f })
			UI.text({ Text = formatValue(state.board, r.value), Font = UI.Fonts.bold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = UI.Theme.accent, Size = UDim2.fromOffset(200, 38), Position = UDim2.new(1, -212, 0, 0), Parent = f })
		end
	end

	return {
		frame = p.frame,
		onOpen = function()
			fetch()
		end,
	}
end

function Leaderboard.init()
	UI.register("Leaderboard", build)
end

return Leaderboard
