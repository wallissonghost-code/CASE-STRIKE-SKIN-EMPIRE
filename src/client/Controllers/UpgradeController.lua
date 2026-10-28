-- UpgradeController: oficina de melhorias. Mostra o RESULTADO GARANTIDO (prévia 3D com a melhoria)
-- e o custo exato antes de consumir qualquer recurso.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local RarityConfig = require(Shared.Config.RarityConfig)
local UpgradeRecipes = require(Shared.Config.UpgradeRecipes)
local EconomyConfig = require(Shared.Config.EconomyConfig)

local UI = require(script.Parent.UIController)
local Net = require(script.Parent.Parent.Util.Net)
local Store = require(script.Parent.Parent.Util.Store)

local Upgrade = {}

local function materialsText(mats, have)
	local parts = {}
	for _, key in ipairs({ "scrap", "pigment", "core" }) do
		local need = mats[key]
		if need then
			local ok = (have[key] or 0) >= need
			table.insert(parts, '<font color="#' .. (ok and "7CE08F" or "F06470") .. '">' .. need .. " " .. EconomyConfig.Materials[key].displayName .. "</font>")
		end
	end
	return table.concat(parts, " • ")
end

local function build()
	local p = UI.createPanel("🔧 Oficina de Melhorias", 1080, 620)
	local state = { selected = nil, preview = nil }

	local matsL = UI.text({ Font = UI.Fonts.bold, TextSize = 14, Size = UDim2.new(1, 0, 0, 20), Parent = p.content })
	UI.text({ Text = "Materiais são obtidos vendendo skins, em missões, presentes e coleções.", TextSize = 12, TextColor3 = UI.Theme.muted, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 20), Parent = p.content })

	local list = UI.scroll({ Size = UDim2.new(0, 330, 1, -44), Position = UDim2.fromOffset(0, 44), Parent = p.content })
	UI.list(list, 6)

	local previewBox = UI.frame({ BackgroundColor3 = UI.Theme.bg, BackgroundTransparency = 0.3, Size = UDim2.new(0, 330, 0, 300), Position = UDim2.fromOffset(344, 44), Parent = p.content })
	UI.corner(previewBox, 12)
	local previewTitle = UI.text({ Font = UI.Fonts.title, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(0, 330, 0, 46), Position = UDim2.fromOffset(344, 350), Parent = p.content })
	local previewNote = UI.text({ TextSize = 13, TextColor3 = UI.Theme.muted, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(0, 330, 0, 60), Position = UDim2.fromOffset(344, 398), Parent = p.content })

	local recipes = UI.scroll({ Size = UDim2.new(1, -690, 1, -44), Position = UDim2.fromOffset(690, 44), Parent = p.content })
	UI.list(recipes, 8)

	local renderPreview

	local function renderRecipes(view, item)
		UI.clear(recipes)
		if not item then
			UI.text({ Text = "Escolha uma skin à esquerda.", TextColor3 = UI.Theme.muted, Size = UDim2.new(1, 0, 0, 40), Parent = recipes })
			return
		end
		local def = SkinDefinitions.ById[item.defId]
		for i, r in ipairs(UpgradeRecipes.List) do
			local applied = item.upgrades[r.id] == true
			local tierOk = RarityConfig.tier(def.rarity) >= r.minRarityTier
			local cost = UpgradeRecipes.creditCost(r, def.value)
			local enoughMats = true
			for k, v in pairs(r.materials) do
				if (view.materials[k] or 0) < v then
					enoughMats = false
				end
			end
			local f = UI.make("TextButton", { Text = "", AutoButtonColor = true, BackgroundColor3 = UI.Theme.panel2, Size = UDim2.new(1, -8, 0, 116), LayoutOrder = i, Parent = recipes })
			UI.corner(f, 10)
			UI.stroke(f, state.preview == r.id and UI.Theme.accent or UI.Theme.stroke, 2, state.preview == r.id and 0.1 or 0.85)
			UI.text({ Text = r.displayName .. (applied and "  ✔" or ""), Font = UI.Fonts.bold, TextSize = 15, Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 6), Parent = f })
			UI.text({ Text = "Resultado garantido: " .. r.effect, TextSize = 12, TextColor3 = UI.Theme.good, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 28), Parent = f })
			local costTxt = "₵ " .. Format.int(cost) .. " • " .. materialsText(r.materials, view.materials)
			if not tierOk then
				costTxt = "Requer raridade " .. RarityConfig.Rarities[RarityConfig.Order[r.minRarityTier]].displayName .. " ou superior"
			end
			UI.text({ Text = costTxt, TextSize = 12, Size = UDim2.new(1, -130, 0, 34), Position = UDim2.fromOffset(10, 60), Parent = f })
			local btn = UI.button({
				Text = applied and "Aplicada" or "Aplicar",
				color = UI.Theme.accent,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -8, 1, -8),
				Size = UDim2.fromOffset(110, 36),
				Parent = f,
				onClick = function()
					UI.confirm({
						title = "Aplicar " .. r.displayName .. "?",
						message = "Skin: " .. def.name .. "\nResultado garantido: " .. r.effect .. "\nCusto: ₵ " .. Format.int(cost) .. " e materiais. A skin NÃO é consumida e não há risco de perda.",
						confirmText = "Aplicar",
						onConfirm = function()
							UI.handle(Net.call("UpgradeAction", { action = "apply", uid = item.uid, recipeId = r.id }), "Melhoria aplicada!")
						end,
					})
				end,
			})
			UI.setEnabled(btn, (not applied) and tierOk and enoughMats and view.credits >= cost and item.location == "inventory", UI.Theme.accent)
			f.Activated:Connect(function()
				state.preview = r.id
				renderPreview(view, item)
				renderRecipes(view, item)
			end)
		end
	end

	renderPreview = function(view, item)
		UI.clear(previewBox)
		if not item then
			previewTitle.Text = ""
			previewNote.Text = ""
			return
		end
		local def = SkinDefinitions.ById[item.defId]
		local ups = {}
		for k, v in pairs(item.upgrades) do
			ups[k] = v
		end
		if state.preview then
			ups[state.preview] = true
		end
		UI.skinViewport(def, ups, UDim2.fromScale(1, 1), { spin = true, inspect = ups.inspect == true }).Parent = previewBox
		previewTitle.Text = def.name
		previewNote.Text = state.preview and ("Prévia com: " .. UpgradeRecipes.ById[state.preview].displayName) or "Toque em uma receita para ver a prévia do resultado."
		if item.location == "bank" then
			previewNote.Text = "Skin no banco: retire-a antes de melhorar."
		end
	end

	local function refresh(view)
		local m = view.materials
		matsL.Text = "Materiais: " .. (m.scrap or 0) .. " Sucata • " .. (m.pigment or 0) .. " Pigmento • " .. (m.core or 0) .. " Núcleo Polido   |   Saldo: ₵ " .. Format.short(view.credits)
		UI.clear(list)
		local items = {}
		for _, item in ipairs(view.items) do
			table.insert(items, item)
		end
		table.sort(items, function(a, b)
			return SkinDefinitions.ById[a.defId].value > SkinDefinitions.ById[b.defId].value
		end)
		for i = 1, math.min(60, #items) do
			local item = items[i]
			local def = SkinDefinitions.ById[item.defId]
			local count = 0
			for _ in pairs(item.upgrades) do
				count = count + 1
			end
			local row = UI.button({
				Text = "",
				color = state.selected == item.uid and UI.Theme.panel:Lerp(UI.Theme.accent, 0.3) or UI.Theme.panel2,
				Size = UDim2.new(1, -8, 0, 50),
				LayoutOrder = i,
				Parent = list,
				onClick = function()
					state.selected = item.uid
					state.preview = nil
					refresh(Store.view)
				end,
			})
			UI.make("UIStroke", { Color = UI.rarityColor(def.rarity), Thickness = 1.5, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = row })
			UI.text({ Text = def.name, Font = UI.Fonts.bold, TextSize = 13, Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 5), Parent = row })
			UI.text({
				Text = RarityConfig.Rarities[def.rarity].displayName .. " • " .. count .. "/5 melhorias" .. (item.location == "bank" and " • no banco" or ""),
				TextSize = 11,
				TextColor3 = UI.rarityColor(def.rarity),
				Size = UDim2.new(1, -20, 0, 16),
				Position = UDim2.fromOffset(10, 27),
				Parent = row,
			})
		end
		local item = state.selected and Store.item(state.selected)
		if not item then
			state.selected = nil
		end
		renderPreview(view, item)
		renderRecipes(view, item)
	end

	return {
		frame = p.frame,
		onOpen = function(args)
			if args and args.uid then
				state.selected = args.uid
				state.preview = nil
			end
		end,
		refresh = refresh,
	}
end

function Upgrade.init()
	UI.register("Upgrade", build)
end

return Upgrade
