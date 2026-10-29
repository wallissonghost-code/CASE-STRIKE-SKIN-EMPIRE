-- EggController: painel de Ovos (chances exibidas com sorte e evento), animação de chocar
-- e painel de Poções (comprar com moedas, usar e ver as fontes de sorte).

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local EventConfig = require(Shared.Config.EventConfig)
local Odds = require(Shared.Logic.Odds)
local Format = require(Shared.Util.Format)

local UI = require(script.Parent.UIController)
local Net = require(script.Parent.Parent.Util.Net)
local Store = require(script.Parent.Parent.Util.Store)

local Eggs = {}

local selected = "basico"
local hatching = false

local function eventDef(view)
	if not view.event then
		return nil
	end
	for _, t in ipairs(EventConfig.Types) do
		if t.id == view.event.id then
			return t
		end
	end
	return nil
end

local function pctText(p)
	if p >= 0.1 then
		return string.format("%.1f%%", p * 100):gsub("%.", ",")
	end
	return (string.format("%.2f%%", p * 100):gsub("%.", ","))
end

---------------------------------------------------------------------------
-- animação de chocar
---------------------------------------------------------------------------

local function reveal(data, eggId)
	local overlay = UI.layers.Overlay
	UI.clear(overlay)
	local shade = UI.frame({ BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), Parent = overlay })
	local egg = GameConfig.Eggs[eggId]
	local eggFrame = UI.frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(170, 220), BackgroundColor3 = UI.rgb(egg.color), Parent = shade })
	UI.corner(eggFrame, 85)
	UI.stroke(eggFrame, Color3.new(1, 1, 1), 4, 0.3)
	local reduce = Store.view and Store.view.settings and Store.view.settings.reduceEffects
	if not reduce then
		for i = 1, 6 do
			TweenService:Create(eggFrame, TweenInfo.new(0.1), { Rotation = (i % 2 == 0) and 12 or -12 }):Play()
			task.wait(0.12)
		end
	else
		task.wait(0.3)
	end
	eggFrame:Destroy()
	local s = GameConfig.SpeciesById[data.speciesId]
	local card = UI.frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(420, 420), BackgroundColor3 = UI.Theme.panel, Parent = shade })
	UI.corner(card, 18)
	UI.stroke(card, UI.rarityColor(s.rarity), 4, 0)
	local vp = UI.creatureViewport(data.speciesId, data.mutationId, UDim2.new(1, -40, 0, 230), { spin = true, zoom = 1.3 })
	vp.Position = UDim2.fromOffset(20, 14)
	vp.Parent = card
	UI.text({ Text = UI.creatureName(data.speciesId, data.mutationId, true), Font = UI.Fonts.title, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 248), Parent = card })
	local m = GameConfig.Mutations[data.mutationId]
	UI.text({
		Text = GameConfig.Rarities[s.rarity].displayName .. "  •  +$" .. Format.short(s.income * m.mult) .. "/s" .. (data.isNew and "  •  <font color='#FFD84A'>NOVO NO ÍNDICE!</font>" or ""),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 290),
		Parent = card,
	})
	local row = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 50), Position = UDim2.fromOffset(20, 340), Parent = card })
	UI.list(row, 12, true, Enum.HorizontalAlignment.Center)
	UI.button({ Text = "OK", color = UI.Theme.panel2, Size = UDim2.fromOffset(150, 46), Parent = row, onClick = function()
		UI.clear(overlay)
	end })
	UI.button({ Text = "ABRIR OUTRO", color = UI.Theme.good, Size = UDim2.fromOffset(200, 46), Parent = row, onClick = function()
		UI.clear(overlay)
		Eggs.hatch(eggId)
	end })
	if GameConfig.tier(s.rarity) >= 5 or m.tier >= 3 then
		UI.toast("✨ " .. UI.creatureName(data.speciesId, data.mutationId) .. "!", "rare")
	end
end

function Eggs.hatch(eggId)
	if hatching then
		return
	end
	hatching = true
	local res = Net.call("EggAction", { action = "hatch", eggId = eggId })
	if UI.handle(res) then
		UI.close(true)
		task.spawn(function()
			reveal(res.data, eggId)
		end)
	end
	hatching = false
end

---------------------------------------------------------------------------
-- painel de ovos
---------------------------------------------------------------------------

local function buildEggs()
	local p = UI.createPanel("🥚 Ovos", 860, 560, "EggShop")
	local tabs = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(0, 220, 1, 0), Parent = p.content })
	UI.list(tabs, 8)
	local detail = UI.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(236, 0), Size = UDim2.new(1, -236, 1, 0), Parent = p.content })
	local header = UI.text({ Text = "", Font = UI.Fonts.title, TextSize = 24, Size = UDim2.new(1, 0, 0, 30), Parent = detail })
	local info = UI.text({ Text = "", TextSize = 14, TextColor3 = UI.Theme.muted, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 32), Parent = detail })
	local list = UI.scroll({ Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 1, -140), Parent = detail })
	UI.list(list, 4)
	local openBtn = UI.button({ Text = "ABRIR", color = UI.Theme.good, TextSize = 20, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 54), Parent = detail, onClick = function()
		Eggs.hatch(selected)
	end })

	local function refresh(view)
		UI.clear(tabs)
		for i, id in ipairs(GameConfig.EggOrder) do
			local egg = GameConfig.Eggs[id]
			local locked = view.rebirths < egg.requiredRebirths
			UI.button({
				Text = egg.name .. "\n$" .. Format.short(egg.price) .. (locked and "  🔒" or ""),
				TextSize = 16,
				LayoutOrder = i,
				color = id == selected and UI.rgb(egg.color) or UI.Theme.panel2,
				Size = UDim2.new(1, 0, 0, 64),
				Parent = tabs,
				onClick = function()
					selected = id
					refresh(Store.view)
				end,
			})
		end
		local egg = GameConfig.Eggs[selected]
		local ev = eventDef(view)
		local species = Odds.speciesTable(egg.rarityWeights, view.luck)
		local mutations = Odds.mutationTable(view.luck, ev)
		header.Text = egg.name .. " — $" .. Format.int(egg.price)
		info.Text = "Sorte +" .. math.floor(view.luck * 100 + 0.5) .. "%" .. (ev and ("  •  " .. ev.icon .. " " .. ev.name) or "") .. "  •  Vagas: " .. #view.creatures .. "/" .. view.slots .. "\nAs chances abaixo já incluem sua sorte e o evento ativo."
		UI.clear(list)
		local shown = Odds.displayPercents(species, 2)
		for i, e in ipairs(species) do
			local s = GameConfig.SpeciesById[e.speciesId]
			local row = UI.frame({ BackgroundColor3 = UI.Theme.panel2, Size = UDim2.new(1, -8, 0, 30), LayoutOrder = i, Parent = list })
			UI.corner(row, 8)
			UI.text({ Text = UI.creatureName(e.speciesId, "normal", true) .. "  <font color='#9FB5A8'>" .. GameConfig.Rarities[s.rarity].displayName .. " • +$" .. Format.short(s.income) .. "/s</font>", TextSize = 15, Size = UDim2.new(1, -100, 1, 0), Position = UDim2.fromOffset(10, 0), Parent = row })
			UI.text({ Text = string.gsub(string.format("%.2f%%", shown[i]), "%.", ","), Font = UI.Fonts.bold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0, 90, 1, 0), Position = UDim2.new(1, -96, 0, 0), Parent = row })
		end
		local mutText = {}
		for _, e in ipairs(mutations) do
			local m = GameConfig.Mutations[e.mutationId]
			table.insert(mutText, m.name .. " ×" .. m.mult .. ": " .. pctText(e.p))
		end
		UI.text({ Text = "<b>Mutações:</b> " .. table.concat(mutText, "  •  "), TextSize = 14, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -8, 0, 0), LayoutOrder = 100, Parent = list })
		local locked = view.rebirths < egg.requiredRebirths
		local full = #view.creatures >= view.slots
		openBtn.Text = locked and "🔒 Libera depois do 1º renascimento" or (full and "Base cheia — venda ou compre pedestais" or ("ABRIR $" .. Format.short(egg.price)))
		UI.setEnabled(openBtn, not locked and not full and view.coins >= egg.price, UI.Theme.good)
	end

	return {
		frame = p.frame,
		refresh = refresh,
		onOpen = function(args)
			if args and args.eggId and GameConfig.Eggs[args.eggId] then
				selected = args.eggId
			end
		end,
	}
end

---------------------------------------------------------------------------
-- painel de poções
---------------------------------------------------------------------------

local function buildPotions()
	local p = UI.createPanel("🧪 Poções e sorte", 760, 520, "PotionShop")
	local list = UI.scroll({ Size = UDim2.fromScale(1, 1), Parent = p.content })
	UI.list(list, 8)
	return {
		frame = p.frame,
		refresh = function(view)
			UI.clear(list)
			local now = Store.serverNow()
			for i, id in ipairs(GameConfig.PotionOrder) do
				local def = GameConfig.Potions[id]
				local row = UI.frame({ Size = UDim2.new(1, -8, 0, 84), LayoutOrder = i, Parent = list })
				UI.corner(row, 12)
				local active = (view.activePotions[id] or 0) - now
				UI.text({ Text = def.icon .. " <b>" .. def.name .. "</b>  (" .. (view.potions[id] or 0) .. " guardadas)" .. (active > 0 and ("  <font color='#7CFF8A'>ativa " .. Format.duration(active) .. "</font>") or ""), TextSize = 17, Size = UDim2.new(1, -330, 0, 28), Position = UDim2.fromOffset(12, 8), Parent = row })
				UI.text({ Text = def.description .. " Dura " .. Format.duration(def.duration) .. " (acumula até " .. Format.duration(def.maxStack) .. ").", TextSize = 13, TextColor3 = UI.Theme.muted, Size = UDim2.new(1, -330, 0, 40), Position = UDim2.fromOffset(12, 36), Parent = row })
				local use = UI.button({ Text = "USAR", color = UI.Theme.good, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -170, 0.5, 0), Size = UDim2.fromOffset(140, 44), Parent = row, onClick = function()
					UI.handle(Net.call("EggAction", { action = "usePotion", potionId = id }), def.name .. " ativada!")
				end })
				UI.setEnabled(use, (view.potions[id] or 0) > 0, UI.Theme.good)
				local buy = UI.button({ Text = "COMPRAR $" .. Format.short(def.coinPrice), TextSize = 14, color = UI.Theme.accent, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 44), Parent = row, onClick = function()
					UI.handle(Net.call("EggAction", { action = "buyPotion", potionId = id }), "Comprada!")
				end })
				UI.setEnabled(buy, view.coins >= def.coinPrice, UI.Theme.accent)
			end
			local sources = {}
			for _, s in ipairs(view.luckSources or {}) do
				table.insert(sources, s.name .. " +" .. math.floor(s.luck * 100 + 0.5) .. "%")
			end
			UI.text({
				Text = "<b>Sua sorte agora: +" .. math.floor(view.luck * 100 + 0.5) .. "%</b> (máximo +" .. math.floor(GameConfig.Luck.Max * 100) .. "%)\n" .. (#sources > 0 and table.concat(sources, "  •  ") or "Nenhuma fonte ativa: use uma Poção da Sorte, renasça ou espere a Hora da Sorte.") .. "\nPoções só se ganham jogando ou com moedas do jogo — nunca com Robux.",
				TextSize = 14,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, -8, 0, 0),
				LayoutOrder = 10,
				Parent = list,
			})
		end,
	}
end

function Eggs.init()
	UI.register("Eggs", buildEggs)
	UI.register("Potions", buildPotions)
end

return Eggs
