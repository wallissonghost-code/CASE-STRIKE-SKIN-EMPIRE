-- CollectionController: catálogo completo (60 skins), coleções, filtros, pesquisa e recompensas de coleção.
-- Skins não descobertas aparecem como silhuetas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local CaseDefinitions = require(Shared.Config.CaseDefinitions)
local RarityConfig = require(Shared.Config.RarityConfig)
local ProgressionConfig = require(Shared.Config.ProgressionConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local SkinModelFactory = require(Shared.Visual.SkinModelFactory)

local UI = require(script.Parent.UIController)
local Net = require(script.Parent.Parent.Util.Net)

local Collections = {}

local function silhouette(def)
	local model = SkinModelFactory.build(def, {})
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Color = Color3.fromRGB(12, 12, 18)
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0
		end
	end
	return UI.viewport(model, UDim2.fromScale(1, 1), {})
end

local function build()
	local p = UI.createPanel("📖 Índice de Coleções", 1120, 640, "Collections")
	local state = { collection = "all", rarity = "all", search = "", onlyMissing = false }

	local summary = UI.text({ Font = UI.Fonts.bold, TextSize = 15, Size = UDim2.new(1, 0, 0, 20), Parent = p.content })

	-- coleções (lado esquerdo)
	local cols = UI.scroll({ Size = UDim2.new(0, 330, 1, -28), Position = UDim2.fromOffset(0, 28), Parent = p.content })
	UI.list(cols, 8)

	-- filtros
	local bar = UI.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(344, 28), Size = UDim2.new(1, -344, 0, 36), Parent = p.content })
	UI.list(bar, 8, true)
	local render
	local colBtn = UI.button({ Text = "", TextSize = 13, color = UI.Theme.panel2, Size = UDim2.fromOffset(170, 34), Parent = bar })
	local rarBtn = UI.button({ Text = "", TextSize = 13, color = UI.Theme.panel2, Size = UDim2.fromOffset(150, 34), Parent = bar })
	local missBtn = UI.button({ Text = "", TextSize = 13, color = UI.Theme.panel2, Size = UDim2.fromOffset(150, 34), Parent = bar })
	local search = UI.make("TextBox", { PlaceholderText = "🔎 Pesquisar", Text = "", ClearTextOnFocus = false, Font = UI.Fonts.body, TextSize = 14, TextColor3 = UI.Theme.text, BackgroundColor3 = UI.Theme.panel2, Size = UDim2.fromOffset(180, 34), Parent = bar })
	UI.corner(search, 10)

	local colOrder = { "all" }
	for _, c in ipairs(CaseDefinitions.List) do
		table.insert(colOrder, c.id)
	end
	local rarOrder = { "all" }
	for _, r in ipairs(RarityConfig.Order) do
		table.insert(rarOrder, r)
	end
	local function nextOf(list, cur)
		for i, v in ipairs(list) do
			if v == cur then
				return list[(i % #list) + 1]
			end
		end
		return list[1]
	end

	local grid = UI.scroll({ Position = UDim2.fromOffset(344, 72), Size = UDim2.new(1, -344, 1, -72), Parent = p.content })
	UI.make("UIGridLayout", { CellSize = UDim2.fromOffset(140, 150), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })

	-- cartões criados uma vez (60 itens fixos); só o conteúdo muda
	local cards = {}
	for i, def in ipairs(SkinDefinitions.List) do
		local card = UI.frame({ BackgroundColor3 = UI.Theme.panel2, LayoutOrder = i, Parent = grid })
		UI.corner(card, 10)
		local stroke = UI.make("UIStroke", { Thickness = 2, Transparency = 0.4, Color = UI.rarityColor(def.rarity), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
		local slot = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 70), Parent = card })
		local name = UI.text({ Font = UI.Fonts.bold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -6, 0, 30), Position = UDim2.fromOffset(3, 70), Parent = card })
		local info = UI.text({ TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -6, 0, 44), Position = UDim2.fromOffset(3, 100), Parent = card })
		cards[def.id] = { card = card, stroke = stroke, slot = slot, name = name, info = info, shownState = nil }
	end

	render = function(view)
		colBtn.Text = state.collection == "all" and "Todas coleções" or CaseDefinitions.ById[state.collection].name
		rarBtn.Text = state.rarity == "all" and "Todas raridades" or RarityConfig.Rarities[state.rarity].displayName
		missBtn.Text = state.onlyMissing and "Só não descobertas" or "Todas as skins"

		local found = 0
		for _ in pairs(view.discovered) do
			found = found + 1
		end
		local complete = 0
		for _, c in pairs(view.collections) do
			if c.complete then
				complete = complete + 1
			end
		end
		summary.Text = "Descobertas: " .. found .. " / " .. SkinDefinitions.Count .. " (" .. math.floor(found / SkinDefinitions.Count * 100 + 0.5) .. "%)   •   Coleções completas: " .. complete .. " / " .. #CaseDefinitions.List

		UI.clear(cols)
		for i, c in ipairs(CaseDefinitions.List) do
			local st = view.collections[c.id]
			local f = UI.frame({ BackgroundColor3 = UI.Theme.panel2:Lerp(UI.rgb(c.color), 0.2), Size = UDim2.new(1, -8, 0, 112), LayoutOrder = i, Parent = cols })
			UI.corner(f, 10)
			UI.text({ Text = c.collectionName, Font = UI.Fonts.bold, TextSize = 15, Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 6), Parent = f })
			UI.text({ Text = st.discovered .. " / " .. st.total .. " descobertas (" .. math.floor(st.discovered / st.total * 100 + 0.5) .. "%) • " .. c.name, TextSize = 12, TextColor3 = UI.Theme.muted, Size = UDim2.new(1, -20, 0, 16), Position = UDim2.fromOffset(10, 28), Parent = f })
			local back = UI.frame({ BackgroundColor3 = UI.Theme.bg, Size = UDim2.new(1, -130, 0, 8), Position = UDim2.fromOffset(10, 50), Parent = f })
			UI.corner(back, 4)
			local fill = UI.frame({ BackgroundColor3 = UI.rgb(c.trim), Size = UDim2.fromScale(st.discovered / st.total, 1), Parent = back })
			UI.corner(fill, 4)
			local reward = ProgressionConfig.CollectionRewards[c.id]
			local titleDef = reward.title and ProgressionConfig.Titles[reward.title]
			local extras = {}
			for _, kind in ipairs(ProgressionConfig.CollectionCosmetics) do
				local owned = view.cosmetics[kind .. "_" .. c.id]
				table.insert(extras, (owned and "✔ " or "") .. ProgressionConfig.CosmeticNames[kind])
			end
			UI.text({
				Text = "Prêmio: " .. UI.rewardText(reward, Format, CaseDefinitions, EconomyConfig)
					.. (titleDef and (" • título “" .. titleDef.displayName .. "”") or "")
					.. "\n" .. table.concat(extras, " • "),
				TextSize = 11,
				Size = UDim2.new(1, -130, 0, 44),
				Position = UDim2.fromOffset(10, 62),
				Parent = f,
			})
			local btn = UI.button({
				Text = st.claimed and "Resgatado" or (st.complete and "Resgatar" or "Incompleta"),
				TextSize = 13,
				color = UI.Theme.good,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(106, 38),
				Parent = f,
				onClick = function()
					UI.handle(Net.call("ClaimReward", { action = "claimCollection", collectionId = c.id }), "Recompensa da coleção resgatada!")
				end,
			})
			UI.setEnabled(btn, st.complete and not st.claimed, UI.Theme.good)
			f.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					state.collection = c.id
					render(view)
				end
			end)
		end

		for _, def in ipairs(SkinDefinitions.List) do
			local c = cards[def.id]
			local disc = view.discovered[def.id] ~= nil
			local visible = (state.collection == "all" or def.collection == state.collection)
				and (state.rarity == "all" or def.rarity == state.rarity)
				and (not state.onlyMissing or not disc)
				and (state.search == "" or (disc and string.find(string.lower(def.name), state.search, 1, true) ~= nil))
			c.card.Visible = visible
			if visible then
				local wanted = disc and "shown" or "hidden"
				if c.shownState ~= wanted then
					c.shownState = wanted
					UI.clear(c.slot)
					local vp = disc and UI.skinViewport(def, {}, UDim2.fromScale(1, 1), {}) or silhouette(def)
					vp.Parent = c.slot
				end
				c.name.Text = disc and def.name or "???"
				c.info.Text = '<font color="#' .. UI.rarityColor(def.rarity):ToHex() .. '">' .. RarityConfig.Rarities[def.rarity].displayName .. "</font> • ₵ " .. Format.short(def.value) .. "\n" .. CaseDefinitions.ById[def.caseId].name
				c.card.BackgroundColor3 = disc and UI.Theme.panel2 or UI.Theme.bg
				-- moldura da coleção (cosmético desbloqueado ao resgatar a coleção)
				local framed = view.cosmetics["frame_" .. def.collection] == true
				c.stroke.Thickness = framed and 3.5 or 2
				c.stroke.Color = framed and UI.rgb(CaseDefinitions.ById[def.collection].trim) or UI.rarityColor(def.rarity)
			end
		end
	end

	local lastView
	colBtn.Activated:Connect(function()
		state.collection = nextOf(colOrder, state.collection)
		if lastView then
			render(lastView)
		end
	end)
	rarBtn.Activated:Connect(function()
		state.rarity = nextOf(rarOrder, state.rarity)
		if lastView then
			render(lastView)
		end
	end)
	missBtn.Activated:Connect(function()
		state.onlyMissing = not state.onlyMissing
		if lastView then
			render(lastView)
		end
	end)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		state.search = string.lower(search.Text)
		if lastView then
			render(lastView)
		end
	end)

	return {
		frame = p.frame,
		refresh = function(view)
			lastView = view
			render(view)
		end,
	}
end

function Collections.init()
	UI.register("Collections", build)
end

return Collections
