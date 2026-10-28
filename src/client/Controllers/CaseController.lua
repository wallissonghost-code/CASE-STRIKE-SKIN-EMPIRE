-- CaseController: pedidos de abertura e a roleta horizontal animada.
-- O servidor já decidiu o prêmio antes da animação; a roleta apenas desacelera até ele.
-- Os itens de preenchimento da faixa são sorteados no cliente só para efeito visual.
-- Elementos da roleta são reaproveitados (pool) entre aberturas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local CaseDefinitions = require(Shared.Config.CaseDefinitions)
local RarityConfig = require(Shared.Config.RarityConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Probability = require(Shared.Logic.Probability)

local UI = require(script.Parent.UIController)
local Net = require(script.Parent.Parent.Util.Net)
local Store = require(script.Parent.Parent.Util.Store)
local Signal = require(script.Parent.Parent.Util.Signal)

local CaseController = {}
CaseController.busy = false
CaseController.autoActive = false
CaseController.autoChanged = Signal.new()

local CATEGORY_ICON = { Pistol = "🔫", SMG = "🔫", Rifle = "🎯", Sniper = "🔭", Knife = "🔪" }
local CARDS_PER_STRIP = 36
local WINNER_INDEX = 31
local CLIP_WIDTH = 1060

local overlay, stripArea, revealArea, autoBar, autoLabel, skipButton
local strips = {} -- pool: { frame, cards = {} }
local skipRequested = false
local rng = Random.new()

---------------------------------------------------------------------------
-- construção da sobreposição
---------------------------------------------------------------------------

local function buildOverlay()
	overlay = UI.frame({
		Name = "Roulette",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Active = true,
		Parent = UI.layers.Overlay,
	})
	stripArea = UI.frame({
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(CLIP_WIDTH, 560),
		Parent = overlay,
	})
	UI.list(stripArea, 6, false, Enum.HorizontalAlignment.Center)
	stripArea.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	revealArea = UI.frame({
		BackgroundColor3 = UI.Theme.panel,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(900, 520),
		Visible = false,
		Parent = overlay,
	})
	UI.corner(revealArea, 16)
	UI.stroke(revealArea, UI.Theme.accent, 2, 0.3)

	autoBar = UI.frame({
		BackgroundColor3 = UI.Theme.panel,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(520, 60),
		Visible = false,
		Parent = overlay,
	})
	UI.corner(autoBar, 12)
	autoLabel = UI.text({ Text = "", Font = UI.Fonts.bold, TextSize = 17, Size = UDim2.new(1, -200, 1, 0), Position = UDim2.fromOffset(16, 0), Parent = autoBar })
	UI.button({
		Text = "⏹ PARAR",
		color = UI.Theme.bad,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(170, 44),
		Parent = autoBar,
		onClick = function()
			CaseController.stopAuto()
		end,
	})

	skipButton = UI.button({
		Text = "⏩ Pular animação",
		color = UI.Theme.panel2,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(190, 42),
		Parent = overlay,
		onClick = function()
			skipRequested = true
		end,
	})
end

local function getStrip(i)
	if strips[i] then
		return strips[i]
	end
	local clip = UI.frame({
		Name = "Strip" .. i,
		BackgroundColor3 = UI.Theme.bg,
		BackgroundTransparency = 0.2,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(CLIP_WIDTH, 150),
		LayoutOrder = i,
		Parent = stripArea,
	})
	UI.corner(clip, 10)
	local belt = UI.frame({ Name = "Belt", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = clip })
	local cards = {}
	for c = 1, CARDS_PER_STRIP do
		local card = UI.frame({ BackgroundColor3 = UI.Theme.panel2, Parent = belt })
		UI.corner(card, 8)
		local bar = UI.frame({ Name = "Bar", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 6), Parent = card })
		local icon = UI.text({ Name = "Icon", TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true, Size = UDim2.new(1, 0, 0.45, 0), Position = UDim2.fromScale(0, 0.06), Parent = card })
		local name = UI.text({
			Name = "Name",
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = UI.Fonts.bold,
			TextScaled = true,
			Size = UDim2.new(1, -8, 0.36, 0),
			Position = UDim2.new(0, 4, 0.52, 0),
			Parent = card,
		})
		UI.make("UITextSizeConstraint", { MaxTextSize = 15, Parent = name })
		cards[c] = { frame = card, bar = bar, icon = icon, name = name }
	end
	local marker = UI.frame({
		Name = "Marker",
		BackgroundColor3 = UI.Theme.accent,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 4, 1, 0),
		ZIndex = 5,
		Parent = clip,
	})
	strips[i] = { clip = clip, belt = belt, cards = cards, marker = marker }
	return strips[i]
end

local function paintCard(card, def, compact)
	local color = UI.rarityColor(def.rarity)
	card.frame.BackgroundColor3 = UI.Theme.panel2:Lerp(color, 0.28)
	card.bar.BackgroundColor3 = color
	card.icon.Text = CATEGORY_ICON[def.category] or "★"
	card.icon.Visible = not compact
	card.name.Text = compact and def.finish or (def.weaponName .. "\n" .. def.finish)
	if compact then
		card.name.Size = UDim2.new(1, -8, 0.8, 0)
		card.name.Position = UDim2.new(0, 4, 0.05, 0)
	else
		card.name.Size = UDim2.new(1, -8, 0.36, 0)
		card.name.Position = UDim2.new(0, 4, 0.52, 0)
	end
end

---------------------------------------------------------------------------
-- animação
---------------------------------------------------------------------------

local function fillerPicker(caseId)
	local entries = Probability.computeTable(CaseDefinitions.ById[caseId], Store.view and Store.view.luck.total or 0)
	return function()
		return Probability.pick(entries, rng:NextNumber()).skinId
	end
end

local function spin(result, fast)
	local quantity = #result.results
	local rowHeight = quantity == 1 and 160 or (quantity == 5 and 92 or 48)
	local cardWidth = quantity == 1 and 130 or (quantity == 5 and 104 or 92)
	local gap = 6
	local step = cardWidth + gap
	local compact = quantity == 10
	local duration
	if fast then
		duration = EconomyConfig.Opening.FastSpinSeconds
	elseif quantity == 1 then
		duration = EconomyConfig.Opening.NormalSpinSeconds
	else
		duration = EconomyConfig.Opening.MultiSpinSeconds
	end
	local pick = fillerPicker(result.caseId)

	for i, s in ipairs(strips) do
		s.clip.Visible = i <= quantity
	end
	local tweens = {}
	for i, r in ipairs(result.results) do
		local s = getStrip(i)
		s.clip.Visible = true
		s.clip.Size = UDim2.fromOffset(CLIP_WIDTH, rowHeight)
		s.belt.Position = UDim2.fromOffset(0, 0)
		for c, card in ipairs(s.cards) do
			local defId = (c == WINNER_INDEX) and r.defId or pick()
			paintCard(card, SkinDefinitions.ById[defId], compact)
			card.frame.Size = UDim2.fromOffset(cardWidth, rowHeight - 12)
			card.frame.Position = UDim2.fromOffset((c - 1) * step, 6)
		end
		-- parada com deslocamento aleatório dentro do cartão vencedor (visual)
		local offset = rng:NextNumber(-cardWidth * 0.38, cardWidth * 0.38)
		local finalX = CLIP_WIDTH / 2 - (WINNER_INDEX - 1) * step - cardWidth / 2 + offset
		local d = duration + (quantity > 1 and (i - 1) * 0.06 or 0)
		local tw = TweenService:Create(s.belt, TweenInfo.new(d, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(finalX, 0) })
		table.insert(tweens, { tween = tw, belt = s.belt, finalX = finalX })
		tw:Play()
	end

	skipRequested = false
	local t0 = os.clock()
	local total = duration + (quantity - 1) * 0.06 + 0.1
	while os.clock() - t0 < total do
		if skipRequested then
			for _, t in ipairs(tweens) do
				t.tween:Cancel()
				t.belt.Position = UDim2.fromOffset(t.finalX, 0)
			end
			break
		end
		RunService.RenderStepped:Wait()
	end
	-- destaca o vencedor
	for i = 1, quantity do
		local card = strips[i].cards[WINNER_INDEX]
		local st = card.frame:FindFirstChild("Win") or UI.make("UIStroke", { Name = "Win", Thickness = 3, Color = Color3.new(1, 1, 1), Parent = card.frame })
		st.Enabled = true
	end
	task.wait(fast and 0.15 or 0.35)
	for i = 1, quantity do
		local st = strips[i].cards[WINNER_INDEX].frame:FindFirstChild("Win")
		if st then
			st.Enabled = false
		end
	end
end

---------------------------------------------------------------------------
-- revelação
---------------------------------------------------------------------------

local function showReveal(result, opts)
	UI.clear(revealArea)
	stripArea.Visible = false
	revealArea.Visible = true
	local quantity = #result.results
	local total = 0
	local uids = {}
	for _, r in ipairs(result.results) do
		total = total + SkinDefinitions.ById[r.defId].value
		table.insert(uids, r.uid)
	end
	UI.text({
		Text = quantity == 1 and "Você obteve!" or ("Você obteve " .. quantity .. " skins!"),
		Font = UI.Fonts.title,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 12),
		Parent = revealArea,
	})
	local grid = UI.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 60), Size = UDim2.new(1, -40, 1, -150), Parent = revealArea })
	local cell = quantity == 1 and UDim2.fromOffset(360, 340) or (quantity == 5 and UDim2.fromOffset(160, 300) or UDim2.fromOffset(160, 150))
	UI.make("UIGridLayout", {
		CellSize = cell,
		CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	for i, r in ipairs(result.results) do
		local def = SkinDefinitions.ById[r.defId]
		local color = UI.rarityColor(def.rarity)
		local card = UI.frame({ BackgroundColor3 = UI.Theme.panel2:Lerp(color, 0.2), LayoutOrder = i, Parent = grid })
		UI.corner(card, 10)
		UI.stroke(card, color, 2, 0.1)
		local vpHeight = quantity == 10 and 70 or (quantity == 1 and 220 or 170)
		local vp = UI.skinViewport(def, {}, UDim2.new(1, 0, 0, vpHeight), { spin = quantity < 10 })
		vp.Parent = card
		UI.text({
			Text = def.name,
			Font = UI.Fonts.bold,
			TextSize = quantity == 1 and 20 or 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -8, 0, quantity == 1 and 26 or 34),
			Position = UDim2.fromOffset(4, vpHeight),
			Parent = card,
		})
		UI.text({
			Text = RarityConfig.Rarities[def.rarity].displayName .. " • ₵ " .. Format.short(def.value),
			TextSize = quantity == 1 and 17 or 12,
			TextColor3 = color,
			Font = UI.Fonts.bold,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -8, 0, 20),
			Position = UDim2.fromOffset(4, vpHeight + (quantity == 1 and 28 or 34)),
			Parent = card,
		})
		if r.isNew then
			local tag = UI.text({
				Text = "NOVA!",
				Font = UI.Fonts.bold,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				BackgroundTransparency = 0,
				BackgroundColor3 = UI.Theme.good,
				Size = UDim2.fromOffset(56, 20),
				Position = UDim2.fromOffset(6, 6),
				Parent = card,
			})
			UI.corner(tag, 6)
		end
	end
	UI.text({
		Text = "Valor total: ₵ " .. Format.int(total) .. "  •  Custo: " .. (result.usedFree and "grátis" or ("₵ " .. Format.int(result.cost))),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = UI.Theme.muted,
		Size = UDim2.new(1, 0, 0, 20),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -68),
		Parent = revealArea,
	})
	if opts.auto then
		return
	end
	local row = UI.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(1, -40, 0, 46), Parent = revealArea })
	UI.list(row, 10, true, Enum.HorizontalAlignment.Center)
	UI.button({
		Text = "✔ Guardar",
		color = UI.Theme.good,
		Size = UDim2.fromOffset(170, 44),
		Parent = row,
		onClick = function()
			CaseController.hide()
		end,
	})
	UI.button({
		Text = "₵ Vender tudo (" .. Format.short(total) .. ")",
		color = UI.Theme.bad,
		Size = UDim2.fromOffset(230, 44),
		Parent = row,
		onClick = function()
			UI.confirm({
				title = "Vender estas skins?",
				message = "Você receberá ₵ " .. Format.int(total) .. ". Esta ação não pode ser desfeita.",
				confirmText = "Vender",
				danger = true,
				onConfirm = function()
					local res = Net.call("InventoryAction", { action = "sell", uids = uids })
					if UI.handle(res, "Vendido por ₵ " .. Format.int(total)) then
						CaseController.hide()
					end
				end,
			})
		end,
	})
	UI.button({
		Text = "↻ Abrir novamente",
		color = UI.Theme.accent,
		Size = UDim2.fromOffset(200, 44),
		Parent = row,
		onClick = function()
			CaseController.open(result.caseId, quantity, opts)
		end,
	})
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------

function CaseController.hide()
	if overlay then
		overlay.Visible = false
	end
end

-- opts = { fast = bool, useFree = bool, auto = bool }
function CaseController.open(caseId, quantity, opts)
	opts = opts or {}
	if CaseController.busy then
		return false
	end
	CaseController.busy = true
	local res = Net.call("RequestCaseOpen", {
		action = "open",
		caseId = caseId,
		quantity = quantity,
		fast = opts.fast == true,
		useFree = opts.useFree == true,
		auto = opts.auto == true,
	})
	if not res.ok then
		CaseController.busy = false
		UI.handle(res)
		return false, res
	end
	overlay.Visible = true
	revealArea.Visible = false
	stripArea.Visible = true
	skipButton.Visible = true
	spin(res.data, opts.fast)
	skipButton.Visible = false
	showReveal(res.data, opts)
	if res.data.levelsGained and res.data.levelsGained > 0 then
		UI.toast("⬆️ Subiu de nível!", "good")
	end
	CaseController.busy = false
	return true, res
end

function CaseController.startAuto(caseId, quantity, opts)
	if CaseController.autoActive then
		return
	end
	local res = Net.call("RequestCaseOpen", { action = "startAuto", caseId = caseId, quantity = quantity })
	if not UI.handle(res) then
		return
	end
	CaseController.autoActive = true
	CaseController.autoChanged:Fire(true)
	autoBar.Visible = true
	local maxOpens = res.data.maxOpens
	local count = 0
	task.spawn(function()
		while CaseController.autoActive do
			autoLabel.Text = "AUTOMÁTICO • " .. count .. "/" .. maxOpens .. " aberturas"
			local ok, r = CaseController.open(caseId, quantity, { fast = opts.fast, useFree = opts.useFree, auto = true })
			if not ok then
				if r and r.error == "rate_limited" then
					task.wait(0.5) -- espera o intervalo mínimo do servidor e tenta de novo
				else
					break
				end
			else
				count = r.data.auto and r.data.auto.opens or (count + 1)
				autoLabel.Text = "AUTOMÁTICO • " .. count .. "/" .. maxOpens .. " aberturas"
				task.wait(opts.fast and 0.6 or 1.0)
			end
		end
		CaseController.stopAuto()
	end)
end

function CaseController.stopAuto()
	local wasActive = CaseController.autoActive
	CaseController.autoActive = false
	if autoBar then
		autoBar.Visible = false
	end
	if wasActive then
		task.spawn(function()
			Net.call("RequestCaseOpen", { action = "stopAuto" })
		end)
		CaseController.autoChanged:Fire(false)
		-- mostra botões da última revelação
		task.delay(0.2, function()
			if overlay.Visible and not CaseController.busy then
				CaseController.hide()
			end
		end)
	end
end

function CaseController.init()
	buildOverlay()
	-- anúncio de drops raros de outros jogadores
	Net.on("CaseOpenResult", function(msg)
		if type(msg) == "table" and msg.kind == "rareDrop" then
			local def = SkinDefinitions.ById[msg.defId]
			if def then
				UI.toast("✨ " .. tostring(msg.playerName) .. " obteve " .. def.name .. " (" .. RarityConfig.Rarities[def.rarity].displayName .. ")!", "rare")
			end
		end
	end)
end

return CaseController
