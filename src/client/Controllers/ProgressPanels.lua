-- ProgressPanels: Missões diárias, Presentes, Renascer, Ranking do servidor e Ajustes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)

local UI = require(script.Parent.UIController)
local Net = require(script.Parent.Parent.Util.Net)
local Store = require(script.Parent.Parent.Util.Store)

local Panels = {}

local function buildMissions()
	local p = UI.createPanel("🎯 Missões de hoje", 760, 480, "Missions")
	local info = UI.text({ Text = "", TextSize = 14, TextColor3 = UI.Theme.muted, Size = UDim2.new(1, 0, 0, 22), Parent = p.content })
	local list = UI.scroll({ Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -28), Parent = p.content })
	UI.list(list, 8)
	return {
		frame = p.frame,
		refresh = function(view)
			info.Text = "Novas missões em " .. Format.duration(view.missionsResetIn - (Store.serverNow() - view.serverTime)) .. ". As recompensas crescem com a sua renda."
			UI.clear(list)
			for i, m in ipairs(view.missions) do
				local row = UI.frame({ Size = UDim2.new(1, -8, 0, 76), LayoutOrder = i, Parent = list })
				UI.corner(row, 10)
				UI.text({ Text = "<b>" .. m.description .. "</b>", TextSize = 16, Size = UDim2.new(1, -200, 0, 24), Position = UDim2.fromOffset(12, 8), Parent = row })
				UI.text({ Text = Format.int(math.min(m.progress, m.target)) .. "/" .. Format.int(m.target) .. "  •  Prêmio: " .. UI.rewardText(m.rewardCoins, m.rewardPotions), TextSize = 14, TextColor3 = UI.Theme.muted, Size = UDim2.new(1, -200, 0, 20), Position = UDim2.fromOffset(12, 34), Parent = row })
				local bar = UI.frame({ BackgroundColor3 = UI.Theme.bg, Size = UDim2.new(1, -210, 0, 8), Position = UDim2.fromOffset(12, 60), Parent = row })
				UI.corner(bar, 4)
				UI.frame({ BackgroundColor3 = UI.Theme.toxic, Size = UDim2.fromScale(math.min(1, m.progress / m.target), 1), Parent = bar })
				local ready = m.progress >= m.target and not m.claimed
				local b = UI.button({ Text = m.claimed and "✔ Feito" or (ready and "RESGATAR" or "Em andamento"), color = UI.Theme.good, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(160, 44), Parent = row, onClick = function()
					UI.handle(Net.call("ClaimAction", { action = "mission", missionId = m.id }), "Missão concluída!")
				end })
				UI.setEnabled(b, ready, UI.Theme.good)
			end
		end,
	}
end

local function buildGifts()
	local p = UI.createPanel("🎁 Presente diário", 800, 400, "Gifts")
	local row = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 170), Parent = p.content })
	UI.list(row, 8, true, Enum.HorizontalAlignment.Center)
	local info = UI.text({ Text = "", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 180), Parent = p.content })
	local claim = UI.button({ Text = "RESGATAR", color = UI.Theme.good, TextSize = 20, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 230), Size = UDim2.fromOffset(280, 54), Parent = p.content, onClick = function()
		local res = Net.call("ClaimAction", { action = "gift" })
		UI.handle(res, res.ok and ("🎁 Dia " .. res.data.day .. ": " .. UI.rewardText(res.data.reward.coins, res.data.reward.potions)) or nil)
	end })
	return {
		frame = p.frame,
		refresh = function(view)
			UI.clear(row)
			local g = view.gifts
			for i, r in ipairs(view.giftRewards) do
				local done = i <= g.streak and not (g.available and i >= g.nextStreak)
				local isNext = g.available and i == g.nextStreak
				local cell = UI.frame({ Size = UDim2.fromOffset(98, 160), LayoutOrder = i, BackgroundColor3 = isNext and UI.Theme.good or UI.Theme.panel2, BackgroundTransparency = done and 0.5 or 0, Parent = row })
				UI.corner(cell, 10)
				UI.text({ Text = "Dia " .. i, Font = UI.Fonts.title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 8), Parent = cell })
				UI.text({ Text = UI.rewardText(r.coins, r.potions) .. (done and "\n✔" or ""), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -8, 0, 100), Position = UDim2.fromOffset(4, 44), Parent = cell })
			end
			info.Text = g.available and "Seu presente de hoje está pronto! Volte todos os dias para aumentar a sequência." or ("Próximo presente em " .. Format.duration(g.resetsIn - (Store.serverNow() - view.serverTime)) .. ". Perder um dia recomeça a sequência.")
			UI.setEnabled(claim, g.available, UI.Theme.good)
			claim.Text = g.available and "RESGATAR" or "Volte amanhã"
		end,
	}
end

local function buildRebirth()
	local p = UI.createPanel("♻️ Renascer", 680, 440, "Rebirth")
	local text = UI.text({ Text = "", TextSize = 16, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), Parent = p.content })
	local btn = UI.button({ Text = "RENASCER", color = UI.Theme.purple, TextSize = 20, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(300, 54), Parent = p.content, onClick = function()
		local r = Store.view.rebirth
		UI.confirm({
			title = "Renascer?",
			message = "Você perde TODAS as moedas e as " .. r.creaturesLost .. " criaturas da base. Mantém índice, melhorias e poções. Ganha renda ×" .. string.gsub(tostring(r.incomeAfter), "%.", ",") .. " e sorte +" .. math.floor(r.luckAfter * 100 + 0.5) .. "% para sempre.",
			confirmText = "Renascer",
			danger = true,
			phrase = GameConfig.Rebirth.ConfirmPhrase,
			onConfirm = function(phrase)
				UI.handle(Net.call("ClaimAction", { action = "rebirth", phrase = phrase }), "♻️ Você renasceu!")
			end,
		})
	end })
	return {
		frame = p.frame,
		refresh = function(view)
			local r = view.rebirth
			text.Text = string.format(
				"Renascimentos: <b>%d</b>  •  Renda atual ×%s\n\nPróximo renascimento custa <font color='#FFD84A'><b>$%s</b></font> (você tem $%s).\n\nDepois de renascer:\n• Renda de todas as criaturas ×%s para sempre\n• Sorte +%d%% para sempre\n• Libera o Ovo Lendário\n\nVocê perde as moedas e as criaturas da base. O índice, as melhorias e as poções ficam.",
				view.rebirths,
				string.gsub(tostring(view.incomeMultiplier), "%.", ","),
				Format.short(r.cost),
				Format.short(view.coins),
				string.gsub(tostring(r.incomeAfter), "%.", ","),
				math.floor(r.luckAfter * 100 + 0.5)
			)
			UI.setEnabled(btn, not r.maxed and view.coins >= r.cost, UI.Theme.purple)
			btn.Text = r.maxed and "Máximo atingido" or "RENASCER"
		end,
	}
end

local function buildRanking()
	local p = UI.createPanel("🏆 Ranking do servidor", 720, 480, "Ranking")
	local list = UI.scroll({ Size = UDim2.fromScale(1, 1), Parent = p.content })
	UI.list(list, 6)
	local function load()
		local res = Net.call("RankingRequest", { action = "get" })
		if not res.ok then
			return
		end
		UI.clear(list)
		for i, r in ipairs(res.data) do
			local row = UI.frame({ Size = UDim2.new(1, -8, 0, 46), LayoutOrder = i, Parent = list })
			UI.corner(row, 8)
			UI.text({ Text = "<b>#" .. i .. "  " .. r.name .. "</b>", TextSize = 16, Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromOffset(12, 0), Parent = row })
			UI.text({ Text = "Patrimônio $" .. Format.short(r.netWorth) .. "  •  +$" .. Format.short(r.rate) .. "/s  •  😈 " .. r.stolen .. "  🛡️ " .. r.defended .. "  ♻️ " .. r.rebirths, TextSize = 14, TextColor3 = UI.Theme.muted, Size = UDim2.new(0.6, -12, 1, 0), Position = UDim2.new(0.4, 0, 0, 0), Parent = row })
		end
	end
	return { frame = p.frame, onOpen = function()
		task.spawn(load)
	end }
end

local function buildSettings()
	local p = UI.createPanel("⚙️ Ajustes", 620, 360, "Settings")
	local box = UI.frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = p.content })
	UI.list(box, 10)
	local reduce = UI.button({ Text = "", color = UI.Theme.panel2, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 1, Parent = box, onClick = function()
		local v = Store.view
		UI.handle(Net.call("SettingsAction", { action = "set", key = "reduceEffects", value = not v.settings.reduceEffects }))
	end })
	UI.text({
		Text = "<b>Como jogar</b>\n• Compre criaturas na esteira (tecla E) ou abra ovos.\n• Elas produzem moedas no pedestal: colete na sua base.\n• Entre em bases sem escudo e segure E para roubar; leve para a SUA base.\n• Encoste em quem está roubando você para pegar de volta.\n• Trave a base no terminal azul quando for sair dela.",
		TextSize = 14,
		TextColor3 = UI.Theme.muted,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		Parent = box,
	})
	return {
		frame = p.frame,
		refresh = function(view)
			reduce.Text = (view.settings.reduceEffects and "✔ " or "") .. "Reduzir efeitos (animações e brilhos)"
		end,
	}
end

function Panels.init()
	UI.register("Missions", buildMissions)
	UI.register("Gifts", buildGifts)
	UI.register("Rebirth", buildRebirth)
	UI.register("Ranking", buildRanking)
	UI.register("Settings", buildSettings)
end

return Panels
