-- ShopController: loja em grade e janela própria de cada caixa
-- (modelo, preço, quantidade, modos rápido/automático, recompensas com probabilidade final e valor).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local CaseDefinitions = require(Shared.Config.CaseDefinitions)
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local RarityConfig = require(Shared.Config.RarityConfig)
local Probability = require(Shared.Logic.Probability)

local UI = require(script.Parent.UIController)
local CaseController = require(script.Parent.CaseController)
local Net = require(script.Parent.Parent.Util.Net)
local Store = require(script.Parent.Parent.Util.Store)

local Shop = {}

local function rarestSkins(caseId, n)
	local list = {}
	for _, s in ipairs(SkinDefinitions.ByCase[caseId]) do
		table.insert(list, s)
	end
	table.sort(list, function(a, b)
		return RarityConfig.tier(a.rarity) > RarityConfig.tier(b.rarity)
	end)
	local out = {}
	for i = 1, math.min(n, #list) do
		out[i] = list[i]
	end
	return out
end

---------------------------------------------------------------------------
-- grade da loja
---------------------------------------------------------------------------

local function buildShop()
	local p = UI.createPanel("🛒 Loja de Caixas", 1000, 620, "CaseShop")
	local cards = {}
	local grid = UI.scroll({ Size = UDim2.fromScale(1, 1), Parent = p.content })
	UI.make("UIGridLayout", { CellSize = UDim2.fromOffset(300, 250), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for _, c in ipairs(CaseDefinitions.List) do
		local card = UI.make("TextButton", {
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = UI.Theme.panel2:Lerp(UI.rgb(c.color), 0.25),
			LayoutOrder = c.order,
			Parent = grid,
		})
		UI.corner(card, 14)
		UI.stroke(card, UI.rgb(c.trim), 2, 0.35)
		local vp = UI.caseViewport(c, UDim2.new(1, 0, 0, 120), { spin = true, zoom = 1.25 })
		vp.Parent = card
		UI.text({ Text = c.name, Font = UI.Fonts.title, TextSize = 22, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(12, 118), Parent = card })
		UI.text({ Text = c.collectionName .. " • " .. c.theme, TextSize = 13, TextColor3 = UI.Theme.muted, Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(12, 144), Parent = card })
		local preview = {}
		for _, s in ipairs(rarestSkins(c.id, 3)) do
			table.insert(preview, '<font color="#' .. UI.rarityColor(s.rarity):ToHex() .. '">' .. s.finish .. "</font>")
		end
		UI.text({ Text = "Destaques: " .. table.concat(preview, " • "), TextSize = 12, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(12, 164), Parent = card })
		local price = UI.text({ Text = "₵ " .. Format.int(c.price), Font = UI.Fonts.title, TextSize = 22, TextColor3 = UI.Theme.accent, Size = UDim2.new(0.5, 0, 0, 28), Position = UDim2.fromOffset(12, 210), Parent = card })
		local status = UI.text({ Text = "", Font = UI.Fonts.bold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.5, -20, 0, 28), Position = UDim2.new(0.5, 0, 0, 210), Parent = card })
		card.Activated:Connect(function()
			UI.open("CaseWindow", { caseId = c.id })
		end)
		cards[c.id] = { price = price, status = status }
	end
	return {
		frame = p.frame,
		refresh = function(view)
			for _, c in ipairs(CaseDefinitions.List) do
				local ref = cards[c.id]
				local free = view.freeCases[c.id] or 0
				if not c.available then
					ref.status.Text = "Indisponível"
					ref.status.TextColor3 = UI.Theme.bad
				elseif view.level < c.requiredLevel then
					ref.status.Text = "🔒 Nível " .. c.requiredLevel
					ref.status.TextColor3 = UI.Theme.bad
				elseif free > 0 then
					ref.status.Text = "🎁 " .. free .. " grátis"
					ref.status.TextColor3 = UI.Theme.good
				elseif view.credits >= c.price then
					ref.status.Text = "Disponível"
					ref.status.TextColor3 = UI.Theme.good
				else
					ref.status.Text = "Saldo insuficiente"
					ref.status.TextColor3 = UI.Theme.muted
				end
			end
		end,
	}
end

---------------------------------------------------------------------------
-- janela da caixa
---------------------------------------------------------------------------

local function buildCaseWindow()
	local p = UI.createPanel("Caixa", 1040, 640, "CaseShop")
	local state = { caseId = nil, quantity = 1, fast = false, useFree = false, odds = nil }

	local left = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(0, 360, 1, 0), Parent = p.content })
	local vpHolder = UI.frame({ BackgroundColor3 = UI.Theme.bg, BackgroundTransparency = 0.3, Size = UDim2.new(1, 0, 0, 200), Parent = left })
	UI.corner(vpHolder, 12)
	local themeLabel = UI.text({ Text = "", TextColor3 = UI.Theme.muted, TextSize = 14, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 206), Parent = left })
	local priceLabel = UI.text({ Text = "", Font = UI.Fonts.title, TextSize = 24, TextColor3 = UI.Theme.accent, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 228), Parent = left })

	UI.text({ Text = "Quantidade", Font = UI.Fonts.bold, TextSize = 14, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 264), Parent = left })
	local qtyRow = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 284), Parent = left })
	UI.list(qtyRow, 8, true)
	local qtyButtons = {}
	local refreshControls

	for _, q in ipairs(CaseDefinitions.QuantityOrder) do
		qtyButtons[q] = UI.button({
			Text = "×" .. q,
			color = UI.Theme.panel2,
			Size = UDim2.fromOffset(84, 38),
			Parent = qtyRow,
			onClick = function()
				if Store.view and q > Store.view.maxQuantity then
					UI.toast("×" .. q .. " exige o atributo Limite de abertura múltipla (Atributos).", "error")
					return
				end
				state.quantity = q
				refreshControls()
			end,
		})
	end

	local fastToggle = UI.button({ Text = "", color = UI.Theme.panel2, Size = UDim2.fromOffset(170, 36), Position = UDim2.fromOffset(0, 334), Parent = left })
	local freeToggle = UI.button({ Text = "", color = UI.Theme.panel2, Size = UDim2.fromOffset(180, 36), Position = UDim2.fromOffset(180, 334), Parent = left })
	local totalLabel = UI.text({ Text = "", Font = UI.Fonts.bold, TextSize = 16, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 378), Parent = left })
	local luckLabel = UI.text({ Text = "", TextSize = 13, TextColor3 = UI.Theme.good, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 400), Parent = left })

	local openBtn = UI.button({ Text = "ABRIR", Font = UI.Fonts.title, TextSize = 26, color = UI.Theme.accent, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 424), Parent = left })
	local autoBtn = UI.button({ Text = "🔁 Abertura automática", color = UI.Theme.blue, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 488), Parent = left })

	-- lista de recompensas
	local right = UI.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(380, 0), Size = UDim2.new(1, -380, 1, 0), Parent = p.content })
	UI.text({ Text = "Possíveis recompensas (probabilidade final, já com bônus de sorte)", Font = UI.Fonts.bold, TextSize = 14, Size = UDim2.new(1, 0, 0, 20), Parent = right })
	local list = UI.scroll({ Size = UDim2.new(1, 0, 1, -26), Position = UDim2.fromOffset(0, 24), Parent = right })
	UI.list(list, 6)
	local rows = {}

	local function totalCost()
		local c = CaseDefinitions.ById[state.caseId]
		return c.price * state.quantity
	end

	refreshControls = function()
		local view = Store.view
		local c = CaseDefinitions.ById[state.caseId]
		if not view or not c then
			return
		end
		for q, b in pairs(qtyButtons) do
			b.BackgroundColor3 = q == state.quantity and UI.Theme.accent or UI.Theme.panel2
			b.Text = (q > view.maxQuantity) and ("🔒×" .. q) or ("×" .. q)
		end
		local free = view.freeCases[c.id] or 0
		local canFree = free >= state.quantity
		if not canFree then
			state.useFree = false
		end
		fastToggle.Text = (state.fast and "⚡ Rápida: LIGADA" or "⚡ Rápida: desligada")
		fastToggle.BackgroundColor3 = state.fast and UI.Theme.good or UI.Theme.panel2
		freeToggle.Text = "🎁 Grátis (" .. free .. "): " .. (state.useFree and "usar" or "não usar")
		freeToggle.BackgroundColor3 = state.useFree and UI.Theme.good or UI.Theme.panel2
		UI.setEnabled(freeToggle, canFree)
		if state.useFree then
			totalLabel.Text = "Custo total: grátis (" .. state.quantity .. " caixa(s) grátis)"
		else
			totalLabel.Text = "Custo total: ₵ " .. Format.int(totalCost()) .. "   •   Saldo: ₵ " .. Format.int(view.credits)
		end
		luckLabel.Text = view.luck.total > 0 and ("🍀 Sorte ativa: +" .. Format.percent(view.luck.total, 0) .. " (ver painel Sorte)") or ""
		local locked = view.level < c.requiredLevel
		local affordable = state.useFree or view.credits >= totalCost()
		openBtn.Text = locked and ("🔒 Nível " .. c.requiredLevel) or (CaseController.autoActive and "AUTOMÁTICO ATIVO" or ("ABRIR ×" .. state.quantity))
		UI.setEnabled(openBtn, (not locked) and affordable and c.available and not CaseController.autoActive, UI.Theme.accent)
		UI.setEnabled(autoBtn, (not locked) and affordable and c.available, UI.Theme.blue)
		autoBtn.Text = CaseController.autoActive and "⏹ Parar automático" or "🔁 Abertura automática"
	end

	local function renderOdds()
		local c = CaseDefinitions.ById[state.caseId]
		local view = Store.view
		local entries
		local shown
		if state.odds and state.odds.caseId == c.id then
			entries = state.odds.odds
			shown = {}
			for i, e in ipairs(entries) do
				shown[i] = e.percent
			end
		else
			-- antes da resposta do servidor: mesma fórmula, mesma sorte informada pelo servidor
			entries = Probability.computeTable(c, view and view.luck.total or 0)
			shown = Probability.displayPercents(entries, 3)
		end
		local order = {}
		for i, e in ipairs(entries) do
			table.insert(order, { e = e, pct = shown[i] })
		end
		table.sort(order, function(a, b)
			return a.e.probability < b.e.probability
		end)
		for i, o in ipairs(order) do
			local def = SkinDefinitions.ById[o.e.skinId]
			local row = rows[i]
			if not row then
				local f = UI.frame({ BackgroundColor3 = UI.Theme.panel2, Size = UDim2.new(1, -8, 0, 64), LayoutOrder = i, Parent = list })
				UI.corner(f, 10)
				local bar = UI.frame({ Size = UDim2.new(0, 6, 1, 0), Parent = f })
				UI.corner(bar, 3)
				local vpSlot = UI.frame({ BackgroundTransparency = 1, Size = UDim2.fromOffset(110, 60), Position = UDim2.fromOffset(10, 2), Parent = f })
				local name = UI.text({ Font = UI.Fonts.bold, TextSize = 16, Size = UDim2.new(1, -330, 0, 22), Position = UDim2.fromOffset(126, 8), Parent = f })
				local sub = UI.text({ TextSize = 13, Size = UDim2.new(1, -330, 0, 18), Position = UDim2.fromOffset(126, 34), Parent = f })
				local value = UI.text({ Font = UI.Fonts.bold, TextSize = 16, TextColor3 = UI.Theme.accent, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(110, 22), Position = UDim2.new(1, -230, 0, 20), Parent = f })
				local pct = UI.text({ Font = UI.Fonts.title, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(100, 22), Position = UDim2.new(1, -110, 0, 20), Parent = f })
				row = { frame = f, bar = bar, vpSlot = vpSlot, name = name, sub = sub, value = value, pct = pct, defId = nil }
				rows[i] = row
			end
			if row.defId ~= def.id then
				row.defId = def.id
				UI.clear(row.vpSlot)
				UI.skinViewport(def, {}, UDim2.fromScale(1, 1), {}).Parent = row.vpSlot
			end
			local color = UI.rarityColor(def.rarity)
			row.bar.BackgroundColor3 = color
			row.name.Text = def.name
			local discovered = view and view.discovered[def.id]
			row.sub.Text = '<font color="#' .. color:ToHex() .. '">' .. RarityConfig.Rarities[def.rarity].displayName .. "</font> • " .. SkinDefinitions.Categories[def.category].displayName .. " • " .. c.collectionName .. (discovered and " • ✔ descoberta" or "")
			row.value.Text = "₵ " .. Format.short(def.value)
			row.pct.Text = string.gsub(string.format("%.3f", o.pct), "%.", ",") .. "%"
		end
	end

	local function fetchOdds()
		local caseId = state.caseId
		task.spawn(function()
			local res = Net.call("RequestCaseOpen", { action = "odds", caseId = caseId })
			if res.ok and state.caseId == caseId then
				state.odds = res.data
				renderOdds()
			end
		end)
	end

	fastToggle.Activated:Connect(function()
		state.fast = not state.fast
		Net.call("InventoryAction", { action = "setFastOpen", value = state.fast })
		refreshControls()
	end)
	freeToggle.Activated:Connect(function()
		if freeToggle:GetAttribute("Disabled") then
			return
		end
		state.useFree = not state.useFree
		refreshControls()
	end)
	openBtn.Activated:Connect(function()
		if openBtn:GetAttribute("Disabled") then
			return
		end
		local c = CaseDefinitions.ById[state.caseId]
		local cost = state.useFree and "grátis" or ("₵ " .. Format.int(totalCost()))
		local function go()
			CaseController.open(c.id, state.quantity, { fast = state.fast, useFree = state.useFree })
		end
		if state.quantity > 1 then
			UI.confirm({
				title = "Abrir " .. state.quantity .. "× " .. c.name .. "?",
				message = "Custo total: " .. cost .. ". Os resultados são sorteados no servidor e vão direto para o seu inventário.",
				confirmText = "Abrir",
				onConfirm = go,
			})
		else
			go()
		end
	end)
	autoBtn.Activated:Connect(function()
		if CaseController.autoActive then
			CaseController.stopAuto()
			return
		end
		if autoBtn:GetAttribute("Disabled") then
			return
		end
		local c = CaseDefinitions.ById[state.caseId]
		UI.confirm({
			title = "Iniciar abertura automática?",
			message = "Abre ×" .. state.quantity .. " " .. c.name .. " repetidamente (₵ " .. Format.int(totalCost()) .. " por vez) enquanto houver saldo, até o limite da sessão. Você pode parar a qualquer momento.",
			confirmText = "Iniciar",
			onConfirm = function()
				CaseController.startAuto(c.id, state.quantity, { fast = state.fast, useFree = false })
			end,
		})
	end)
	CaseController.autoChanged:Connect(function()
		refreshControls()
	end)

	return {
		frame = p.frame,
		onOpen = function(args)
			local c = CaseDefinitions.ById[args and args.caseId or "urban"]
			if not c then
				return
			end
			if state.caseId ~= c.id then
				state.caseId = c.id
				state.odds = nil
				state.quantity = 1
				state.useFree = false
				UI.clear(vpHolder)
				UI.caseViewport(c, UDim2.fromScale(1, 1), { spin = true, zoom = 1.1 }).Parent = vpHolder
			end
			if Store.view then
				state.fast = Store.view.settings.fastOpen == true
			end
			p.title.Text = "📦 " .. c.name
			themeLabel.Text = c.collectionName .. " • " .. c.theme .. (c.available and "" or " • INDISPONÍVEL")
			priceLabel.Text = "₵ " .. Format.int(c.price) .. " por caixa"
			fetchOdds()
		end,
		refresh = function(view)
			if not state.caseId then
				return
			end
			refreshControls()
			renderOdds()
			-- a sorte pode ter mudado: pede de novo as probabilidades finais ao servidor
			if state.odds and math.abs((state.odds.luck or 0) - view.luck.total) > 1e-9 then
				fetchOdds()
			end
		end,
	}
end

function Shop.init()
	UI.register("Shop", buildShop)
	UI.register("CaseWindow", buildCaseWindow)
end

return Shop
