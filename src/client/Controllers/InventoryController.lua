-- Inventário em grade com ícones 3D (ViewportFrame), filtros por raridade, ordenação por
-- valor/nome/raridade, busca por nome e paginação (12 por página, cartões reaproveitados).
-- Ações: favoritar, vender (com confirmação para Raro ou melhor), vender repetidos, expor/retirar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDefinitions = require(Shared.ItemDefinitions)
local RarityConfig = require(Shared.RarityConfig)
local ItemModels = require(Shared.Visual.ItemModels)
local Format = require(Shared.Util.Format)

local UI = require(script.Parent.Parent.Util.UI)
local Store = require(script.Parent.Parent.Util.Store)
local Net = require(script.Parent.Parent.Util.Net)
local UIController = require(script.Parent.UIController)

local InventoryController = {}

local PAGE_SIZE = 12
local SORTS = {
	{ id = "value", label = "Valor ↓" },
	{ id = "rarity", label = "Raridade ↓" },
	{ id = "name", label = "Nome A-Z" },
}

local filter = { rarity = 0, sort = 1, search = "", page = 1 }
local selectedId
local ui = {}
local cards = {}

-- lista filtrada e ordenada de { item, count }
function InventoryController.entries(view)
	local out = {}
	local rarityFilter = filter.rarity > 0 and RarityConfig.Order[filter.rarity] or nil
	local search = string.lower(filter.search or "")
	for id, count in pairs(view.inventory) do
		local item = ItemDefinitions.get(id)
		if item and count > 0 then
			local okRarity = not rarityFilter or item.rarity == rarityFilter
			local okName = search == "" or string.find(string.lower(item.name), search, 1, true) ~= nil
			if okRarity and okName then
				table.insert(out, { item = item, count = count })
			end
		end
	end
	local sortId = SORTS[filter.sort].id
	table.sort(out, function(a, b)
		if sortId == "name" then
			return a.item.name < b.item.name
		elseif sortId == "rarity" then
			local ra, rb = RarityConfig.rank(a.item.rarity), RarityConfig.rank(b.item.rarity)
			if ra ~= rb then
				return ra > rb
			end
		end
		if a.item.value ~= b.item.value then
			return a.item.value > b.item.value
		end
		return a.item.index < b.item.index
	end)
	return out
end

local function call(payload, okText)
	local r = Net.call("InventoryAction", payload)
	if r.ok and okText then
		UIController.toast(okText(r), "coins")
	elseif not r.ok and not r.needsConfirm then
		UIController.toast(r.message, "warn")
	end
	return r
end

local function sell(itemId, amount)
	local item = ItemDefinitions.get(itemId)
	local function send(confirm)
		local r = call({ action = "sell", itemId = itemId, amount = amount, confirm = confirm }, function(res)
			return "💰 Vendeu " .. res.amount .. "x " .. item.name .. " por " .. Format.int(res.coins) .. " Coins"
		end)
		if r.needsConfirm then
			UIController.confirm("Vender " .. amount .. "x " .. item.name .. " (" .. RarityConfig.get(item.rarity).name .. ") por 💰" .. Format.int(item.value * amount) .. "?", "Vender", function()
				send(true)
			end)
		end
	end
	send(false)
end

local function refreshDetail(view)
	local d = ui.detail
	local item = selectedId and ItemDefinitions.get(selectedId)
	local count = item and view.inventory[selectedId] or 0
	if not item or count <= 0 then
		selectedId = nil
		d.holder.Visible = false
		ui.hint.Visible = true
		return
	end
	ui.hint.Visible = false
	d.holder.Visible = true
	local rarity = RarityConfig.get(item.rarity)
	local displayed = view.displayed[selectedId] or 0
	local fav = view.favorites[selectedId] == true
	ItemModels.showInViewport(d.viewport, selectedId, false)
	d.name.Text = item.name
	d.rarity.Text = rarity.name
	d.rarity.TextColor3 = rarity.color
	d.info.Text = "Valor: 💰" .. Format.int(item.value) .. "\nVocê tem: " .. count .. (displayed > 0 and ("  (" .. displayed .. " na vitrine)") or "")
	d.fav.Text = fav and "★ Favorito" or "☆ Favoritar"
	local sellable = fav and 0 or math.max(0, count - displayed)
	UI.setEnabled(d.sell1, sellable > 0, UI.Theme.coins)
	UI.setEnabled(d.sellAll, sellable > 1, UI.Theme.coins)
	d.sellAll.Text = "Vender " .. sellable
	d.display.Visible = displayed < count
	d.undisplay.Visible = displayed > 0
end

function InventoryController.refresh(view)
	if not ui.grid then
		return
	end
	local entries = InventoryController.entries(view)
	local pages = math.max(1, math.ceil(#entries / PAGE_SIZE))
	filter.page = math.clamp(filter.page, 1, pages)
	for i = 1, PAGE_SIZE do
		local card = cards[i]
		local entry = entries[(filter.page - 1) * PAGE_SIZE + i]
		card.frame.Visible = entry ~= nil
		if entry then
			local rarity = RarityConfig.get(entry.item.rarity)
			card.itemId = entry.item.id
			ItemModels.showInViewport(card.viewport, entry.item.id, false)
			card.name.Text = entry.item.name
			card.value.Text = "💰" .. Format.short(entry.item.value)
			card.count.Text = "x" .. entry.count
			card.strip.BackgroundColor3 = rarity.color
			card.fav.Visible = view.favorites[entry.item.id] == true
			card.shown.Visible = (view.displayed[entry.item.id] or 0) > 0
			card.frame.BackgroundColor3 = (entry.item.id == selectedId) and UI.Theme.cardLight or UI.Theme.card
		end
	end
	ui.empty.Visible = #entries == 0
	ui.empty.Text = next(view.inventory) and "Nenhum objeto com este filtro." or "Inventário vazio. Use uma máquina para ganhar objetos!"
	ui.page.Text = filter.page .. "/" .. pages
	ui.capacity.Text = "🎒 " .. view.itemCount .. "/" .. view.capacity .. " objetos"
	ui.rarityButton.Text = "Raridade: " .. (filter.rarity > 0 and RarityConfig.get(RarityConfig.Order[filter.rarity]).name or "Todas")
	ui.sortButton.Text = "Ordem: " .. SORTS[filter.sort].label
	refreshDetail(view)
end

local function build(content)
	-- filtros
	ui.search = UI.make("TextBox", {
		Name = "Search",
		PlaceholderText = "🔎 Buscar por nome",
		Text = "",
		ClearTextOnFocus = false,
		BackgroundColor3 = UI.Theme.bg,
		TextColor3 = UI.Theme.text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		Size = UDim2.new(0, 220, 0, 38),
		Parent = content,
	})
	UI.corner(ui.search, 10)
	UI.make("UITextSizeConstraint", { MaxTextSize = 18, Parent = ui.search })
	ui.search:GetPropertyChangedSignal("Text"):Connect(function()
		filter.search = ui.search.Text
		filter.page = 1
		if Store.view then
			InventoryController.refresh(Store.view)
		end
	end)
	ui.rarityButton = UI.button(content, "Raridade: Todas", UI.Theme.cardLight, function()
		filter.rarity = (filter.rarity + 1) % (#RarityConfig.Order + 1)
		filter.page = 1
		InventoryController.refresh(Store.view)
	end, { Position = UDim2.new(0, 228, 0, 0), Size = UDim2.new(0, 200, 0, 38), MaxText = 18 })
	ui.sortButton = UI.button(content, "Ordem: Valor", UI.Theme.cardLight, function()
		filter.sort = (filter.sort % #SORTS) + 1
		InventoryController.refresh(Store.view)
	end, { Position = UDim2.new(0, 434, 0, 0), Size = UDim2.new(0, 180, 0, 38), MaxText = 18 })

	-- grade 4×3
	ui.grid = UI.make("Frame", { Name = "Grid", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(0, 488, 0, 330), Parent = content })
	UI.make("UIGridLayout", { CellSize = UDim2.new(0, 116, 0, 106), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ui.grid })
	for i = 1, PAGE_SIZE do
		local card = {}
		card.frame = UI.make("TextButton", { Name = "Card" .. i, Text = "", AutoButtonColor = true, BackgroundColor3 = UI.Theme.card, LayoutOrder = i, Parent = ui.grid })
		UI.corner(card.frame, 10)
		card.strip = UI.frame(card.frame, { Size = UDim2.new(1, 0, 0, 5), radius = 3 })
		card.viewport = UI.viewport(card.frame, { Position = UDim2.new(0, 6, 0, 8), Size = UDim2.new(1, -12, 0, 56), BackgroundTransparency = 1 })
		card.name = UI.label(card.frame, "", { Position = UDim2.new(0, 6, 0, 64), Size = UDim2.new(1, -12, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, MaxText = 13 })
		card.value = UI.label(card.frame, "", { Position = UDim2.new(0, 6, 0, 83), Size = UDim2.new(0.6, -6, 0, 18), TextColor3 = UI.Theme.coins, MaxText = 13 })
		card.count = UI.label(card.frame, "", { Position = UDim2.new(0.6, 0, 0, 83), Size = UDim2.new(0.4, -6, 0, 18), TextXAlignment = Enum.TextXAlignment.Right, MaxText = 14 })
		card.fav = UI.label(card.frame, "★", { Position = UDim2.new(0, 4, 0, 6), Size = UDim2.new(0, 20, 0, 20), TextColor3 = UI.Theme.coins, MaxText = 18 })
		card.shown = UI.label(card.frame, "🏛️", { Position = UDim2.new(1, -24, 0, 6), Size = UDim2.new(0, 20, 0, 20), MaxText = 16 })
		card.frame.Activated:Connect(function()
			selectedId = card.itemId
			InventoryController.refresh(Store.view)
		end)
		cards[i] = card
	end
	ui.empty = UI.label(content, "", { Position = UDim2.new(0, 0, 0, 160), Size = UDim2.new(0, 488, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Theme.muted, MaxText = 20 })

	-- detalhe do objeto selecionado
	local side = UI.frame(content, { Position = UDim2.new(0, 498, 0, 46), Size = UDim2.new(1, -498, 0, 330), BackgroundColor3 = UI.Theme.bg })
	ui.hint = UI.label(side, "Toque em um objeto para ver as opções.", { Position = UDim2.new(0, 10, 0, 120), Size = UDim2.new(1, -20, 0, 60), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Theme.muted, MaxText = 18 })
	local d = {}
	d.holder = UI.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Visible = false, Parent = side })
	d.viewport = UI.viewport(d.holder, { Position = UDim2.new(0, 10, 0, 8), Size = UDim2.new(1, -20, 0, 100) })
	d.name = UI.label(d.holder, "", { Position = UDim2.new(0, 10, 0, 110), Size = UDim2.new(1, -20, 0, 26), Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Center, MaxText = 22 })
	d.rarity = UI.label(d.holder, "", { Position = UDim2.new(0, 10, 0, 136), Size = UDim2.new(1, -20, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, MaxText = 16 })
	d.info = UI.label(d.holder, "", { Position = UDim2.new(0, 10, 0, 156), Size = UDim2.new(1, -20, 0, 36), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Theme.muted, MaxText = 14 })
	local half = UDim2.new(0.5, -14, 0, 38)
	d.fav = UI.button(d.holder, "☆ Favoritar", UI.Theme.blue, function()
		call({ action = "favorite", itemId = selectedId, value = not Store.view.favorites[selectedId] })
	end, { Position = UDim2.new(0, 10, 0, 196), Size = UDim2.new(1, -20, 0, 36), MaxText = 18 })
	d.sell1 = UI.button(d.holder, "Vender 1", UI.Theme.coins, function(b)
		if not b:GetAttribute("Disabled") then
			sell(selectedId, 1)
		end
	end, { Position = UDim2.new(0, 10, 0, 238), Size = half, MaxText = 18 })
	d.sellAll = UI.button(d.holder, "Vender todos", UI.Theme.coins, function(b)
		if not b:GetAttribute("Disabled") then
			local v = Store.view
			sell(selectedId, math.max(1, (v.inventory[selectedId] or 0) - (v.displayed[selectedId] or 0)))
		end
	end, { Position = UDim2.new(0.5, 4, 0, 238), Size = half, MaxText = 18 })
	d.display = UI.button(d.holder, "🏛️ Expor", UI.Theme.accent, function()
		call({ action = "display", itemId = selectedId }, function()
			return "🏛️ Exposto na sua vitrine da galeria!"
		end)
	end, { Position = UDim2.new(0, 10, 0, 282), Size = half, MaxText = 18 })
	d.undisplay = UI.button(d.holder, "Retirar", UI.Theme.grey, function()
		local v = Store.view
		for slot, id in ipairs(v.showcase) do
			if id == selectedId then
				call({ action = "undisplay", slot = slot })
				return
			end
		end
	end, { Position = UDim2.new(0.5, 4, 0, 282), Size = half, MaxText = 18 })
	ui.detail = d

	-- rodapé
	ui.capacity = UI.label(content, "", { Position = UDim2.new(0, 0, 1, -40), Size = UDim2.new(0, 190, 0, 36), MaxText = 18 })
	UI.button(content, "Vender repetidos (Comum/Incomum)", UI.Theme.coins, function()
		UIController.confirm("Vender todas as cópias extras de objetos Comuns e Incomuns? Você fica com 1 de cada. Favoritos e itens expostos ficam protegidos.", "Vender", function()
			call({ action = "sellDuplicates" }, function(r)
				return "💰 Vendeu " .. r.amount .. " repetidos por " .. Format.int(r.coins) .. " Coins"
			end)
		end)
	end, { Position = UDim2.new(0, 196, 1, -42), Size = UDim2.new(0, 300, 0, 40), MaxText = 16 })
	UI.button(content, "◀", UI.Theme.cardLight, function()
		filter.page = filter.page - 1
		InventoryController.refresh(Store.view)
	end, { Position = UDim2.new(1, -170, 1, -42), Size = UDim2.new(0, 48, 0, 40) })
	ui.page = UI.label(content, "1/1", { Position = UDim2.new(1, -118, 1, -42), Size = UDim2.new(0, 66, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, MaxText = 20 })
	UI.button(content, "▶", UI.Theme.cardLight, function()
		filter.page = filter.page + 1
		InventoryController.refresh(Store.view)
	end, { Position = UDim2.new(1, -48, 1, -42), Size = UDim2.new(0, 48, 0, 40) })
end

function InventoryController.select(itemId)
	selectedId = itemId
end

function InventoryController.init()
	UIController.register("Inventory", {
		screen = "InventoryUI",
		title = "🎒 Inventário",
		build = build,
		refresh = InventoryController.refresh,
	})
end

return InventoryController
