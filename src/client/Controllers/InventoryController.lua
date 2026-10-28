-- InventoryController: inventário em grade com filtros, pesquisa, ordenação e paginação
-- (cartões reaproveitados entre páginas), painel de detalhes e inspeção 3D.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local RarityConfig = require(Shared.Config.RarityConfig)
local CaseDefinitions = require(Shared.Config.CaseDefinitions)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local UpgradeRecipes = require(Shared.Config.UpgradeRecipes)

local UI = require(script.Parent.UIController)
local Net = require(script.Parent.Parent.Util.Net)
local Store = require(script.Parent.Parent.Util.Store)

local Inventory = {}

local PAGE_SIZE = 20

local FILTERS = {
	location = { { "all", "Todos" }, { "inventory", "No inventário" }, { "bank", "No banco" }, { "equipped", "Equipados" }, { "favorite", "Favoritos" } },
	rarity = { { "all", "Todas raridades" }, { "Common", "Comum" }, { "Uncommon", "Incomum" }, { "Rare", "Rara" }, { "Epic", "Épica" }, { "Legendary", "Lendária" }, { "Secret", "Secreta" } },
	category = { { "all", "Todas categorias" }, { "Pistol", "Pistolas" }, { "SMG", "Submetralhadoras" }, { "Rifle", "Rifles" }, { "Sniper", "Precisão" }, { "Knife", "Facas" } },
	sort = { { "value", "Maior valor" }, { "rarity", "Raridade" }, { "recent", "Mais recentes" }, { "name", "Nome" } },
}

local function cycle(list, current)
	for i, e in ipairs(list) do
		if e[1] == current then
			return list[(i % #list) + 1]
		end
	end
	return list[1]
end
local function labelOf(list, current)
	for _, e in ipairs(list) do
		if e[1] == current then
			return e[2]
		end
	end
	return list[1][2]
end

-- inspeção 3D em tela cheia
function Inventory.inspect(item)
	local def = SkinDefinitions.ById[item.defId]
	local shade = UI.make("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, Size = UDim2.fromScale(1, 1), Parent = UI.layers.Modal })
	local vp = UI.skinViewport(def, item.upgrades, UDim2.new(1, 0, 0.8, 0), { spin = true, inspect = item.upgrades.inspect == true, zoom = 0.9 })
	vp.Parent = shade
	UI.text({
		Text = def.name .. "\n<font size='16' color='#" .. UI.rarityColor(def.rarity):ToHex() .. "'>" .. RarityConfig.Rarities[def.rarity].displayName .. " • ₵ " .. Format.int(def.value) .. "</font>",
		Font = UI.Fonts.title,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0.12, 0),
		Position = UDim2.fromScale(0, 0.8),
		Parent = shade,
	})
	UI.text({ Text = "Toque para fechar • modelo provisório", TextSize = 13, TextColor3 = UI.Theme.muted, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -28), Parent = shade })
	shade.Activated:Connect(function()
		shade:Destroy()
	end)
end

local function build()
	local p = UI.createPanel("🎒 Itens e Equipamentos", 1120, 640)
	local state = { location = "all", rarity = "all", category = "all", sort = "value", search = "", page = 1, selected = nil }

	-- barra de filtros
	local bar = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Parent = p.content })
	UI.list(bar, 8, true)
	local filterButtons = {}
	local renderGrid
	for _, key in ipairs({ "location", "rarity", "category", "sort" }) do
		filterButtons[key] = UI.button({
			Text = "",
			TextSize = 14,
			color = UI.Theme.panel2,
			Size = UDim2.fromOffset(key == "sort" and 140 or 150, 36),
			Parent = bar,
			onClick = function()
				state[key] = cycle(FILTERS[key], state[key])[1]
				state.page = 1
				renderGrid()
			end,
		})
	end
	local search = UI.make("TextBox", {
		PlaceholderText = "🔎 Pesquisar",
		Text = "",
		ClearTextOnFocus = false,
		Font = UI.Fonts.body,
		TextSize = 15,
		TextColor3 = UI.Theme.text,
		BackgroundColor3 = UI.Theme.panel2,
		Size = UDim2.fromOffset(170, 36),
		Parent = bar,
	})
	UI.corner(search, 10)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		state.search = string.lower(search.Text)
		state.page = 1
		renderGrid()
	end)
	local bulkBtn = UI.button({ Text = "Vender comuns", TextSize = 14, color = UI.Theme.bad, Size = UDim2.fromOffset(140, 36), Parent = bar })

	local countLabel = UI.text({ Text = "", TextSize = 13, TextColor3 = UI.Theme.muted, Size = UDim2.new(0, 640, 0, 18), Position = UDim2.fromOffset(0, 44), Parent = p.content })

	-- grade (cartões reaproveitados)
	local gridArea = UI.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 66), Size = UDim2.new(0, 660, 1, -110), Parent = p.content })
	UI.make("UIGridLayout", { CellSize = UDim2.fromOffset(124, 118), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = gridArea })
	local cards = {}
	for i = 1, PAGE_SIZE do
		local card = UI.make("TextButton", { Text = "", AutoButtonColor = true, BackgroundColor3 = UI.Theme.panel2, LayoutOrder = i, Visible = false, Parent = gridArea })
		UI.corner(card, 10)
		local stroke = UI.make("UIStroke", { Thickness = 2, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
		local frameGrad = UI.make("UIGradient", { Enabled = false, Color = ColorSequence.new(Color3.fromRGB(255, 210, 80), Color3.fromRGB(255, 80, 200)), Parent = stroke })
		local vpSlot = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), Parent = card })
		local name = UI.text({ TextSize = 12, Font = UI.Fonts.bold, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -6, 0, 30), Position = UDim2.fromOffset(3, 62), Parent = card })
		local value = UI.text({ TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Theme.accent, Font = UI.Fonts.bold, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 96), Parent = card })
		local flags = UI.text({ TextSize = 13, Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 3), TextXAlignment = Enum.TextXAlignment.Right, Parent = card })
		local entry = { card = card, stroke = stroke, frameGrad = frameGrad, vpSlot = vpSlot, name = name, value = value, flags = flags, uid = nil, modelKey = nil }
		card.Activated:Connect(function()
			if entry.uid then
				state.selected = entry.uid
				Inventory._renderDetails()
			end
		end)
		cards[i] = entry
	end

	-- paginação
	local pager = UI.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(0, 660, 0, 38), Parent = p.content })
	local prevBtn = UI.button({ Text = "◀", color = UI.Theme.panel2, Size = UDim2.fromOffset(60, 36), Parent = pager })
	local pageLabel = UI.text({ Text = "", TextXAlignment = Enum.TextXAlignment.Center, Font = UI.Fonts.bold, Size = UDim2.new(1, -140, 1, 0), Position = UDim2.fromOffset(70, 0), Parent = pager })
	local nextBtn = UI.button({ Text = "▶", color = UI.Theme.panel2, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(60, 36), Parent = pager })

	-- detalhes
	local details = UI.frame({ BackgroundColor3 = UI.Theme.panel2, BackgroundTransparency = 0.2, Position = UDim2.new(0, 676, 0, 44), Size = UDim2.new(1, -676, 1, -44), Parent = p.content })
	UI.corner(details, 12)
	UI.padding(details, 12)

	local filtered = {}

	local function matches(item, def)
		if state.location == "inventory" and item.location ~= "inventory" then
			return false
		elseif state.location == "bank" and item.location ~= "bank" then
			return false
		elseif state.location == "equipped" and not item.equipped then
			return false
		elseif state.location == "favorite" and not item.favorite then
			return false
		end
		if state.rarity ~= "all" and def.rarity ~= state.rarity then
			return false
		end
		if state.category ~= "all" and def.category ~= state.category then
			return false
		end
		if state.search ~= "" and not string.find(string.lower(def.name), state.search, 1, true) then
			return false
		end
		return true
	end

	renderGrid = function()
		local view = Store.view
		if not view then
			return
		end
		for key, b in pairs(filterButtons) do
			b.Text = labelOf(FILTERS[key], state[key])
		end
		filtered = {}
		for _, item in ipairs(view.items) do
			local def = SkinDefinitions.ById[item.defId]
			if def and matches(item, def) then
				table.insert(filtered, { item = item, def = def })
			end
		end
		table.sort(filtered, function(a, b)
			if state.sort == "rarity" then
				local ta, tb = RarityConfig.tier(a.def.rarity), RarityConfig.tier(b.def.rarity)
				if ta ~= tb then
					return ta > tb
				end
			elseif state.sort == "recent" then
				if a.item.obtainedAt ~= b.item.obtainedAt then
					return (a.item.obtainedAt or 0) > (b.item.obtainedAt or 0)
				end
			elseif state.sort == "name" then
				if a.def.name ~= b.def.name then
					return a.def.name < b.def.name
				end
			end
			if a.def.value ~= b.def.value then
				return a.def.value > b.def.value
			end
			return a.item.uid < b.item.uid
		end)
		local pages = math.max(1, math.ceil(#filtered / PAGE_SIZE))
		state.page = math.clamp(state.page, 1, pages)
		pageLabel.Text = "Página " .. state.page .. " de " .. pages
		countLabel.Text = #view.items .. " / " .. view.inventoryCapacity .. " skins • " .. #filtered .. " no filtro • vagas de exibição: " .. view.equipSlots
		for i = 1, PAGE_SIZE do
			local entry = cards[i]
			local f = filtered[(state.page - 1) * PAGE_SIZE + i]
			if not f then
				entry.card.Visible = false
				entry.uid = nil
			else
				entry.card.Visible = true
				entry.uid = f.item.uid
				local color = UI.rarityColor(f.def.rarity)
				entry.card.BackgroundColor3 = UI.Theme.panel2:Lerp(color, 0.18)
				entry.stroke.Color = f.item.upgrades.frame and Color3.new(1, 1, 1) or color
				entry.frameGrad.Enabled = f.item.upgrades.frame == true
				entry.stroke.Thickness = (state.selected == f.item.uid) and 4 or 2
				entry.name.Text = f.def.name
				entry.value.Text = "₵ " .. Format.short(f.def.value)
				local fl = ""
				if f.item.favorite then
					fl = fl .. "⭐"
				end
				if f.item.equipped then
					fl = fl .. "🎽"
				end
				if f.item.location == "bank" then
					fl = fl .. "🏦"
				end
				entry.flags.Text = fl
				local ups = {}
				for k in pairs(f.item.upgrades) do
					table.insert(ups, k)
				end
				table.sort(ups)
				local key = f.def.id .. ":" .. table.concat(ups, ",")
				if entry.modelKey ~= key then
					entry.modelKey = key
					UI.clear(entry.vpSlot)
					UI.skinViewport(f.def, f.item.upgrades, UDim2.fromScale(1, 1), {}).Parent = entry.vpSlot
				end
			end
		end
		UI.setEnabled(prevBtn, state.page > 1, UI.Theme.panel2)
		UI.setEnabled(nextBtn, state.page < pages, UI.Theme.panel2)
		Inventory._renderDetails()
	end

	prevBtn.Activated:Connect(function()
		state.page = state.page - 1
		renderGrid()
	end)
	nextBtn.Activated:Connect(function()
		state.page = state.page + 1
		renderGrid()
	end)

	bulkBtn.Activated:Connect(function()
		local view = Store.view
		local total, n = 0, 0
		for _, item in ipairs(view.items) do
			local def = SkinDefinitions.ById[item.defId]
			if item.location == "inventory" and not item.favorite and not item.equipped and def.rarity == "Common" then
				total = total + def.value
				n = n + 1
			end
		end
		if n == 0 then
			UI.toast("Nenhuma skin comum disponível para venda (favoritas, equipadas e depositadas são ignoradas).")
			return
		end
		UI.confirm({
			title = "Vender " .. n .. " skins comuns?",
			message = "Você receberá ₵ " .. Format.int(math.floor(total * EconomyConfig.SellRate)) .. ". Favoritas, equipadas e depositadas não são incluídas.",
			confirmText = "Vender",
			danger = true,
			onConfirm = function()
				local res = Net.call("InventoryAction", { action = "sellBulk", maxTier = 1 })
				if res.ok then
					UI.toast("Vendidas " .. res.data.sold .. " skins por ₵ " .. Format.int(res.data.credits), "good")
				else
					UI.handle(res)
				end
			end,
		})
	end)

	local function actionButton(parent, text, color, order, onClick)
		return UI.button({ Text = text, color = color, TextSize = 14, Size = UDim2.new(0.5, -4, 0, 36), LayoutOrder = order, Parent = parent, onClick = onClick })
	end

	function Inventory._renderDetails()
		UI.clear(details)
		local item = state.selected and Store.item(state.selected)
		if not item then
			UI.text({ Text = "Selecione uma skin para ver detalhes, inspecionar, vender, equipar, depositar ou levar à oficina.", TextColor3 = UI.Theme.muted, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = details })
			return
		end
		local def = SkinDefinitions.ById[item.defId]
		local color = UI.rarityColor(def.rarity)
		local vp = UI.skinViewport(def, item.upgrades, UDim2.new(1, 0, 0, 170), { spin = true, inspect = item.upgrades.inspect == true })
		vp.Parent = details
		UI.text({ Text = def.name, Font = UI.Fonts.title, TextSize = 22, Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 172), Parent = details })
		local caseDef = CaseDefinitions.ById[def.caseId]
		local ups = {}
		for _, r in ipairs(UpgradeRecipes.List) do
			if item.upgrades[r.id] then
				table.insert(ups, r.displayName)
			end
		end
		local info = '<font color="#' .. color:ToHex() .. '">' .. RarityConfig.Rarities[def.rarity].displayName .. "</font> • " .. SkinDefinitions.Categories[def.category].displayName
			.. "\nValor: <b>₵ " .. Format.int(def.value) .. "</b>"
			.. "\nColeção: " .. caseDef.name
			.. "\nEstado: " .. (item.location == "bank" and "depositada no banco" or (item.equipped and "equipada (exibição)" or "no inventário"))
			.. (item.favorite and " • ⭐ favorita" or "")
			.. "\nMelhorias: " .. (#ups > 0 and table.concat(ups, ", ") or "nenhuma")
		UI.text({ Text = info, TextSize = 14, Size = UDim2.new(1, 0, 0, 100), Position = UDim2.fromOffset(0, 202), TextYAlignment = Enum.TextYAlignment.Top, Parent = details })

		local actions = UI.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 306), Size = UDim2.new(1, 0, 1, -306), Parent = details })
		UI.make("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 36), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = actions })

		actionButton(actions, "🔍 Inspecionar", UI.Theme.blue, 1, function()
			Inventory.inspect(item)
		end)
		actionButton(actions, item.favorite and "☆ Desfavoritar" or "⭐ Favoritar", UI.Theme.accent, 2, function()
			UI.handle(Net.call("InventoryAction", { action = "favorite", uid = item.uid, value = not item.favorite }))
		end)
		if item.location == "inventory" then
			actionButton(actions, item.equipped and "Desequipar" or "🎽 Equipar", UI.Theme.purple, 3, function()
				UI.handle(Net.call("InventoryAction", { action = item.equipped and "unequip" or "equip", uid = item.uid }))
			end)
			actionButton(actions, "🏦 Depositar", UI.Theme.good, 4, function()
				UI.handle(Net.call("BankAction", { action = "deposit", uid = item.uid }), "Skin depositada no banco.")
			end)
			actionButton(actions, "🔧 Oficina", UI.Theme.panel, 5, function()
				UI.open("Upgrade", { uid = item.uid })
			end)
			actionButton(actions, "₵ Vender", UI.Theme.bad, 6, function()
				local price = math.floor(def.value * EconomyConfig.SellRate)
				local msg = "Vender " .. def.name .. " por ₵ " .. Format.int(price) .. "? Esta ação não pode ser desfeita."
				if item.favorite then
					UI.confirm({
						title = "⚠️ Skin favorita",
						message = msg .. "\n\nEsta skin está marcada como FAVORITA. Para confirmar, digite VENDER.",
						confirmText = "Vender favorita",
						danger = true,
						phrase = "VENDER",
						onConfirm = function()
							if UI.handle(Net.call("InventoryAction", { action = "sell", uids = { item.uid }, confirmFavorites = true }), "Vendida por ₵ " .. Format.int(price)) then
								state.selected = nil
							end
						end,
					})
				else
					UI.confirm({
						title = "Vender skin?",
						message = msg,
						confirmText = "Vender",
						danger = true,
						onConfirm = function()
							if UI.handle(Net.call("InventoryAction", { action = "sell", uids = { item.uid } }), "Vendida por ₵ " .. Format.int(price)) then
								state.selected = nil
							end
						end,
					})
				end
			end)
		else
			actionButton(actions, "↩ Retirar do banco", UI.Theme.good, 3, function()
				UI.handle(Net.call("BankAction", { action = "withdraw", uid = item.uid }), "Skin retirada do banco.")
			end)
			UI.text({ Text = "Skins no banco não podem ser vendidas, equipadas ou melhoradas até serem retiradas.", TextSize = 12, TextColor3 = UI.Theme.muted, LayoutOrder = 9, Parent = actions })
		end
	end

	return {
		frame = p.frame,
		onOpen = function(args)
			if args and args.uid then
				state.selected = args.uid
			end
		end,
		refresh = function()
			renderGrid()
		end,
	}
end

function Inventory.init()
	UI.register("Inventory", build)
end

return Inventory
