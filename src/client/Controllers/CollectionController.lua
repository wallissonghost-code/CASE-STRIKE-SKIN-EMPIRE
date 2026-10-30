-- Livro de coleções: os 20 objetos agrupados por máquina de origem. Os descobertos aparecem
-- em 3D; os que faltam aparecem como silhuetas com "???". Cada parte completa e a coleção
-- inteira dão uma recompensa (Coins, XP e título). Aba "Títulos" para escolher o título exibido.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDefinitions = require(Shared.ItemDefinitions)
local MachineDefinitions = require(Shared.MachineDefinitions)
local RarityConfig = require(Shared.RarityConfig)
local MissionDefinitions = require(Shared.MissionDefinitions)
local ItemModels = require(Shared.Visual.ItemModels)
local Format = require(Shared.Util.Format)

local UI = require(script.Parent.Parent.Util.UI)
local Store = require(script.Parent.Parent.Util.Store)
local Net = require(script.Parent.Parent.Util.Net)
local UIController = require(script.Parent.UIController)

local CollectionController = {}

local ui = { tiles = {}, setButtons = {}, setLabels = {}, titleButtons = {} }
local tab = "book"

local function claim(setId)
	local r = Net.call("ProgressAction", { action = "claimSet", setId = setId })
	if r.ok then
		UIController.toast("🎁 Coleção completa! +" .. Format.int(r.coins) .. " Coins e +" .. r.xp .. " XP", "coins")
	else
		UIController.toast(r.message, "warn")
	end
end

local function rewardText(set)
	local t = "🎁 " .. Format.short(set.coins) .. " + " .. set.xp .. " XP"
	if set.title then
		t = t .. " + título"
	end
	return t
end

function CollectionController.refresh(view)
	if not ui.book then
		return
	end
	ui.book.Visible = tab == "book"
	ui.titles.Visible = tab == "titles"
	ui.setProgress(view.discoveredCount / view.totalItems, "Descobertos " .. view.discoveredCount .. "/" .. view.totalItems)
	for _, item in ipairs(ItemDefinitions.List) do
		local tile = ui.tiles[item.id]
		local found = view.discovered[item.id] ~= nil
		local rarity = RarityConfig.get(item.rarity)
		ItemModels.showInViewport(tile.viewport, item.id, not found)
		tile.name.Text = found and item.name or "???"
		tile.rarity.Text = rarity.name
		tile.rarity.TextColor3 = rarity.color
		tile.frame.BackgroundColor3 = found and UI.Theme.cardLight or UI.Theme.bg
	end
	for _, s in ipairs(view.sets) do
		local set = MissionDefinitions.SetById[s.id]
		local button = ui.setButtons[s.id]
		ui.setLabels[s.id].Text = (set.machine and MachineDefinitions.get(set.machine).name or "Coleção completa") .. "  " .. s.have .. "/" .. s.total
		if s.claimed then
			button.Text = "✔ Resgatado"
			UI.setEnabled(button, false)
		elseif s.have >= s.total then
			button.Text = "RESGATAR " .. rewardText(set)
			UI.setEnabled(button, true, UI.Theme.green)
		else
			button.Text = rewardText(set)
			UI.setEnabled(button, false)
		end
	end
	for id, b in pairs(ui.titleButtons) do
		local unlocked = id == "" or view.titles[id] == true
		if view.title == id then
			b.Text = "✔ Usando"
			UI.setEnabled(b, false)
			b.BackgroundColor3 = UI.Theme.green
		elseif unlocked then
			b.Text = "Usar"
			UI.setEnabled(b, true, UI.Theme.blue)
		else
			b.Text = "🔒"
			UI.setEnabled(b, false)
		end
	end
end

local function buildBook(parent)
	local rows = parent
	UI.list(rows, 6)
	for i, set in ipairs(MissionDefinitions.CollectionSets) do
		local row = UI.frame(rows, { Name = set.id, Size = UDim2.new(1, -10, 0, set.machine and 94 or 44), LayoutOrder = i, BackgroundColor3 = UI.Theme.card })
		ui.setLabels[set.id] = UI.label(row, set.name, { Position = UDim2.new(0, 10, 0, 6), Size = UDim2.new(0, 150, 0, 32), Font = Enum.Font.FredokaOne, TextWrapped = true, MaxText = 18 })
		ui.setButtons[set.id] = UI.button(row, "", UI.Theme.grey, function(b)
			if not b:GetAttribute("Disabled") then
				claim(set.id)
			end
		end, { Name = "Claim", Position = UDim2.new(0, 10, 1, -40), Size = UDim2.new(0, set.machine and 150 or 400, 0, 34), MaxText = 13 })
		if set.machine then
			local tiles = UI.make("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 170, 0, 4), Size = UDim2.new(1, -176, 1, -8), Parent = row })
			UI.list(tiles, 6, true)
			local order = 0
			for _, item in ipairs(ItemDefinitions.List) do
				if item.machine == set.machine then
					order = order + 1
					local tile = {}
					tile.frame = UI.frame(tiles, { Size = UDim2.new(0.2, -5, 1, 0), LayoutOrder = order })
					tile.viewport = UI.viewport(tile.frame, { Position = UDim2.new(0, 4, 0, 2), Size = UDim2.new(1, -8, 0, 46), BackgroundTransparency = 1 })
					tile.name = UI.label(tile.frame, "", { Position = UDim2.new(0, 4, 0, 48), Size = UDim2.new(1, -8, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, MaxText = 12 })
					tile.rarity = UI.label(tile.frame, "", { Position = UDim2.new(0, 4, 0, 66), Size = UDim2.new(1, -8, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, MaxText = 11 })
					ui.tiles[item.id] = tile
				end
			end
		end
	end
end

local function buildTitles(parent)
	local list = UI.scroll(parent, { Size = UDim2.new(1, 0, 1, 0) })
	UI.list(list, 6)
	local entries = { { id = "", name = "Sem título", color = UI.Theme.muted, how = "" } }
	local how = {}
	for _, set in ipairs(MissionDefinitions.CollectionSets) do
		how[set.title] = "Complete: " .. set.name
	end
	for _, a in ipairs(MissionDefinitions.Achievements) do
		if a.title then
			how[a.title] = "Conquista: " .. a.text
		end
	end
	for id, def in pairs(MissionDefinitions.Titles) do
		table.insert(entries, { id = id, name = def.name, color = def.color, how = how[id] or "" })
	end
	table.sort(entries, function(a, b)
		return a.id == "" or (b.id ~= "" and a.name < b.name)
	end)
	for i, e in ipairs(entries) do
		local row = UI.frame(list, { Size = UDim2.new(1, -12, 0, 52), LayoutOrder = i })
		UI.label(row, e.name, { Position = UDim2.new(0, 12, 0, 4), Size = UDim2.new(0.6, 0, 0, 26), TextColor3 = e.color, Font = Enum.Font.FredokaOne, MaxText = 20 })
		UI.label(row, e.how, { Position = UDim2.new(0, 12, 0, 30), Size = UDim2.new(0.7, 0, 0, 18), TextColor3 = UI.Theme.muted, MaxText = 13 })
		ui.titleButtons[e.id] = UI.button(row, "Usar", UI.Theme.blue, function(b)
			if b:GetAttribute("Disabled") then
				return
			end
			local r = Net.call("ProgressAction", { action = "setTitle", titleId = e.id })
			if not r.ok then
				UIController.toast(r.message, "warn")
			end
		end, { Position = UDim2.new(1, -140, 0.5, -20), Size = UDim2.new(0, 128, 0, 40), MaxText = 18 })
	end
end

local function build(content)
	local _, set = UI.progress(content, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0, 300, 0, 30) }, UI.Theme.accent)
	ui.setProgress = set
	local selectTab = UI.tabs(content, { { id = "book", label = "📖 Livro", width = 140 }, { id = "titles", label = "🏷️ Títulos", width = 140 } }, function(id)
		tab = id
		if Store.view then
			CollectionController.refresh(Store.view)
		end
	end, { Position = UDim2.new(1, -292, 0, -4), Size = UDim2.new(0, 292, 0, 38) })
	ui.book = UI.scroll(content, { Name = "Book", Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(1, 0, 1, -40) })
	buildBook(ui.book)
	ui.titles = UI.make("Frame", { Name = "Titles", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(1, 0, 1, -40), Visible = false, Parent = content })
	buildTitles(ui.titles)
	ui.selectTab = selectTab
	selectTab("book")
end

function CollectionController.init()
	UIController.register("Collection", {
		screen = "CollectionUI",
		title = "📖 Livro de Coleções",
		build = build,
		refresh = CollectionController.refresh,
		onOpen = function(args)
			if args.tab and ui.selectTab then
				ui.selectTab(args.tab)
			end
		end,
	})
end

return CollectionController
