-- ProgressionPanels: Missões (diárias, semanais, desafios de evento), Presentes (diário, nível,
-- conquistas), Sorte (fontes e probabilidades finais), Atributos (estatísticas e títulos) e Renascimento.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local CaseDefinitions = require(Shared.Config.CaseDefinitions)
local RarityConfig = require(Shared.Config.RarityConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local ProgressionConfig = require(Shared.Config.ProgressionConfig)
local AchievementDefinitions = require(Shared.Config.AchievementDefinitions)
local LuckConfig = require(Shared.Config.LuckConfig)
local Probability = require(Shared.Logic.Probability)

local UI = require(script.Parent.UIController)
local Net = require(script.Parent.Parent.Util.Net)
local Store = require(script.Parent.Parent.Util.Store)

local Panels = {}

local function rewardText(r)
	return UI.rewardText(r, Format, CaseDefinitions, EconomyConfig)
end

local function progressRow(parent, order, title, progress, target, reward, claimed, onClaim)
	local f = UI.frame({ BackgroundColor3 = UI.Theme.panel2, Size = UDim2.new(1, -8, 0, 76), LayoutOrder = order, Parent = parent })
	UI.corner(f, 10)
	UI.text({ Text = title, Font = UI.Fonts.bold, TextSize = 15, Size = UDim2.new(1, -150, 0, 20), Position = UDim2.fromOffset(12, 8), Parent = f })
	UI.text({ Text = "Recompensa: " .. rewardText(reward), TextSize = 12, TextColor3 = UI.Theme.accent, Size = UDim2.new(1, -150, 0, 18), Position = UDim2.fromOffset(12, 30), Parent = f })
	local back = UI.frame({ BackgroundColor3 = UI.Theme.bg, Size = UDim2.new(1, -150, 0, 10), Position = UDim2.fromOffset(12, 56), Parent = f })
	UI.corner(back, 5)
	local fill = UI.frame({ BackgroundColor3 = UI.Theme.good, Size = UDim2.fromScale(math.clamp(progress / target, 0, 1), 1), Parent = back })
	UI.corner(fill, 5)
	UI.text({ Text = progress .. "/" .. target, TextSize = 12, Font = UI.Fonts.bold, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(60, 16), Position = UDim2.new(1, -206, 0, 8), Parent = f })
	local done = progress >= target
	local btn = UI.button({
		Text = claimed and "✔ Resgatado" or (done and "Resgatar" or "Em andamento"),
		TextSize = 13,
		color = UI.Theme.good,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(124, 40),
		Parent = f,
		onClick = onClaim,
	})
	UI.setEnabled(btn, done and not claimed, UI.Theme.good)
end

local function section(parent, text, order)
	UI.text({ Text = text, Font = UI.Fonts.title, TextSize = 19, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = order, Parent = parent })
end

---------------------------------------------------------------------------
-- Missões
---------------------------------------------------------------------------

local function buildMissions()
	local p = UI.createPanel("📜 Missões e Eventos", 860, 600, "Missions")
	local list = UI.scroll({ Size = UDim2.fromScale(1, 1), Parent = p.content })
	UI.list(list, 8)
	return {
		frame = p.frame,
		refresh = function(view)
			UI.clear(list)
			local order = 0
			local function nextOrder()
				order = order + 1
				return order
			end
			local now = Store.serverNow()
			if view.event then
				section(list, "🎉 " .. view.event.name .. " — termina em " .. Format.duration(view.event.endsAt - now), nextOrder())
				UI.text({ Text = view.event.description, TextSize = 13, TextColor3 = UI.Theme.muted, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = nextOrder(), Parent = list })
				for _, c in ipairs(view.event.challenges) do
					progressRow(list, nextOrder(), c.description, c.progress, c.target, c.reward, c.claimed, function()
						UI.handle(Net.call("ClaimReward", { action = "claimEventChallenge", challengeId = c.id }), "Desafio concluído!")
					end)
				end
			elseif view.nextEvent then
				UI.text({ Text = "Próximo evento: " .. view.nextEvent.name .. " em " .. Format.duration(view.nextEvent.startsAt - now), TextSize = 14, TextColor3 = UI.Theme.purple, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = nextOrder(), Parent = list })
			end
			local featured = CaseDefinitions.ById[view.featuredCollection]
			UI.text({ Text = "⭐ Coleção em destaque: " .. (featured and featured.name or "—"), TextSize = 14, TextColor3 = UI.Theme.accent, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = nextOrder(), Parent = list })

			section(list, "Diárias — renovam em " .. Format.duration(view.daily.secondsUntilReset - (now - view.serverTime)), nextOrder())
			for _, m in ipairs(view.missions.daily) do
				progressRow(list, nextOrder(), m.description, m.progress, m.target, m.reward, m.claimed, function()
					UI.handle(Net.call("ClaimReward", { action = "claimMission", missionId = m.id }), "Missão concluída!")
				end)
			end
			section(list, "Semanais", nextOrder())
			for _, m in ipairs(view.missions.weekly) do
				progressRow(list, nextOrder(), m.description, m.progress, m.target, m.reward, m.claimed, function()
					UI.handle(Net.call("ClaimReward", { action = "claimMission", missionId = m.id }), "Missão concluída!")
				end)
			end
		end,
	}
end

---------------------------------------------------------------------------
-- Presentes
---------------------------------------------------------------------------

local function buildGifts()
	local p = UI.createPanel("🎁 Presentes", 900, 600, "Rewards")
	local list = UI.scroll({ Size = UDim2.fromScale(1, 1), Parent = p.content })
	UI.list(list, 8)
	return {
		frame = p.frame,
		refresh = function(view)
			UI.clear(list)
			local order = 0
			local function nextOrder()
				order = order + 1
				return order
			end
			local now = Store.serverNow()
			section(list, "Recompensa diária", nextOrder())
			local track = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 120), LayoutOrder = nextOrder(), Parent = list })
			UI.list(track, 8, true)
			for day, r in ipairs(ProgressionConfig.DailyRewards) do
				local isNext = view.daily.available and day == view.daily.nextStreak
				local got = (not view.daily.available and day <= view.daily.streak) or (view.daily.available and day < view.daily.nextStreak)
				local f = UI.frame({ BackgroundColor3 = isNext and UI.Theme.accent or (got and UI.Theme.good or UI.Theme.panel2), Size = UDim2.fromOffset(112, 116), Parent = track })
				UI.corner(f, 10)
				UI.text({ Text = "Dia " .. day, Font = UI.Fonts.title, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 6), Parent = f })
				UI.text({ Text = rewardText(r), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -8, 0, 70), Position = UDim2.fromOffset(4, 34), Parent = f })
			end
			local dailyBtn = UI.button({
				Text = view.daily.available and ("Resgatar dia " .. view.daily.nextStreak) or ("Volte em " .. Format.duration(view.daily.secondsUntilReset - (now - view.serverTime))),
				color = UI.Theme.good,
				Size = UDim2.fromOffset(260, 44),
				LayoutOrder = nextOrder(),
				Parent = list,
				onClick = function()
					UI.handle(Net.call("ClaimReward", { action = "claimDaily" }), "Presente diário resgatado!")
				end,
			})
			UI.setEnabled(dailyBtn, view.daily.available, UI.Theme.good)
			UI.text({ Text = "O dia é contado pelo relógio do servidor (UTC). Pular um dia reinicia a sequência.", TextSize = 12, TextColor3 = UI.Theme.muted, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = nextOrder(), Parent = list })

			section(list, "Recompensas de nível", nextOrder())
			for _, lr in ipairs(view.levelRewards) do
				progressRow(list, nextOrder(), "Alcançar o nível " .. lr.level, math.min(view.level, lr.level), lr.level, ProgressionConfig.LevelRewards[lr.level], lr.claimed, function()
					UI.handle(Net.call("ClaimReward", { action = "claimLevelReward", level = lr.level }), "Recompensa de nível resgatada!")
				end)
			end

			section(list, "Conquistas", nextOrder())
			for _, a in ipairs(view.achievements) do
				local def = AchievementDefinitions.ById[a.id]
				progressRow(list, nextOrder(), def.name .. " — " .. def.description, a.unlocked and def.target or a.progress, def.target, def.reward, a.claimed, function()
					UI.handle(Net.call("ClaimReward", { action = "claimAchievement", achievementId = a.id }), "Conquista resgatada!")
				end)
			end
		end,
	}
end

---------------------------------------------------------------------------
-- Sorte
---------------------------------------------------------------------------

local function buildLuck()
	local p = UI.createPanel("🍀 Sorte", 900, 600)
	local list = UI.scroll({ Size = UDim2.fromScale(1, 1), Parent = p.content })
	UI.list(list, 8)
	return {
		frame = p.frame,
		refresh = function(view)
			UI.clear(list)
			local order = 0
			local function nextOrder()
				order = order + 1
				return order
			end
			local now = Store.serverNow()
			section(list, "Sorte total: +" .. Format.percent(view.luck.total, 1) .. "  (máximo +" .. Format.percent(LuckConfig.MaxTotalLuck, 0) .. ")", nextOrder())
			UI.text({
				Text = "A sorte aumenta o peso das skins Raras, Épicas, Lendárias e Secretas. O servidor recalcula os pesos e as chances finais de cada skin aparecem na janela da caixa — a soma é sempre 100%. Nenhum bônus de sorte é vendido por Robux.",
				TextSize = 13,
				TextColor3 = UI.Theme.muted,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = nextOrder(),
				Parent = list,
			})
			section(list, "Fontes ativas", nextOrder())
			if #view.luck.sources == 0 then
				UI.text({ Text = "Nenhum bônus ativo. Ganhe sorte com o 7º dia do presente diário, missões semanais, eventos e renascimentos.", TextSize = 13, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = nextOrder(), Parent = list })
			end
			for _, s in ipairs(view.luck.sources) do
				local f = UI.frame({ BackgroundColor3 = UI.Theme.panel2, Size = UDim2.new(1, -8, 0, 58), LayoutOrder = nextOrder(), Parent = list })
				UI.corner(f, 10)
				UI.text({ Text = s.displayName .. "  <font color='#7CE08F'>+" .. Format.percent(s.luck, 1) .. "</font>", Font = UI.Fonts.bold, TextSize = 15, Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(12, 8), Parent = f })
				local dur
				if s.kind == "timed" or s.kind == "event" then
					dur = "termina em " .. Format.duration((s.expiresAt or now) - now)
				elseif s.kind == "uses" then
					dur = "restam " .. tostring(s.usesLeft) .. " aberturas"
				else
					dur = "permanente"
				end
				UI.text({ Text = "Origem: " .. s.source .. " • " .. dur, TextSize = 12, TextColor3 = UI.Theme.muted, Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(12, 32), Parent = f })
			end
			section(list, "Chance por raridade (sem sorte → com sua sorte atual)", nextOrder())
			for _, c in ipairs(CaseDefinitions.List) do
				local base = Probability.byRarity(Probability.computeTable(c, 0))
				local mine = Probability.byRarity(Probability.computeTable(c, view.luck.total))
				local parts = {}
				for _, r in ipairs(RarityConfig.Order) do
					if base[r] then
						table.insert(parts, '<font color="#' .. UI.rarityColor(r):ToHex() .. '">' .. RarityConfig.Rarities[r].displayName .. "</font> " .. Format.percent(base[r], 2) .. "→" .. Format.percent(mine[r], 2))
					end
				end
				UI.text({ Text = "<b>" .. c.name .. "</b>: " .. table.concat(parts, "  "), TextSize = 12, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -8, 0, 0), LayoutOrder = nextOrder(), Parent = list })
			end
		end,
	}
end

---------------------------------------------------------------------------
-- Atributos
---------------------------------------------------------------------------

local function buildAttributes()
	local p = UI.createPanel("📊 Atributos do Colecionador", 1000, 620, "Attributes")
	local left = UI.scroll({ Size = UDim2.new(0.56, -8, 1, 0), Parent = p.content })
	UI.list(left, 8)
	local right = UI.scroll({ Size = UDim2.new(0.44, -8, 1, 0), Position = UDim2.new(0.56, 8, 0, 0), Parent = p.content })
	UI.list(right, 6)
	return {
		frame = p.frame,
		refresh = function(view)
			UI.clear(left)
			UI.clear(right)
			section(left, "Atributos", 0)
			for i, a in ipairs(view.attributes) do
				local f = UI.frame({ BackgroundColor3 = UI.Theme.panel2, Size = UDim2.new(1, -8, 0, 96), LayoutOrder = i, Parent = left })
				UI.corner(f, 10)
				UI.text({ Text = a.displayName .. "  <font color='#A5AABE'>nível " .. a.level .. "/" .. a.maxLevel .. "</font>", Font = UI.Fonts.bold, TextSize = 15, Size = UDim2.new(1, -140, 0, 20), Position = UDim2.fromOffset(12, 6), Parent = f })
				UI.text({ Text = a.description, TextSize = 12, TextColor3 = UI.Theme.muted, Size = UDim2.new(1, -140, 0, 30), Position = UDim2.fromOffset(12, 26), Parent = f })
				local benefit = "Atual: " .. a.benefit .. (a.nextBenefit and ("  →  próximo: " .. a.nextBenefit) or "  (máximo)")
				UI.text({ Text = benefit, TextSize = 12, TextColor3 = UI.Theme.good, Size = UDim2.new(1, -140, 0, 18), Position = UDim2.fromOffset(12, 56), Parent = f })
				local maxed = a.level >= a.maxLevel
				local lockedLevel = (not maxed) and view.level < (a.requiredLevel or 0)
				UI.text({
					Text = maxed and "Limite máximo atingido" or ("Custo: ₵ " .. Format.int(a.cost) .. (lockedLevel and ("  • requer nível " .. a.requiredLevel) or "") .. (a.linked and "  • mesma melhoria do Banco" or "")),
					TextSize = 12,
					Font = UI.Fonts.bold,
					TextColor3 = lockedLevel and UI.Theme.bad or UI.Theme.accent,
					Size = UDim2.new(1, -140, 0, 18),
					Position = UDim2.fromOffset(12, 74),
					Parent = f,
				})
				local btn = UI.button({
					Text = maxed and "✔ Máximo" or "Melhorar",
					color = UI.Theme.blue,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(116, 42),
					Parent = f,
					onClick = function()
						UI.handle(Net.call("ProgressionAction", { action = "buyAttribute", attributeId = a.id }), a.displayName .. " melhorado!")
					end,
				})
				UI.setEnabled(btn, (not maxed) and (not lockedLevel) and view.credits >= (a.cost or math.huge), UI.Theme.blue)
			end

			-- estatísticas
			local found = 0
			for _ in pairs(view.discovered) do
				found = found + 1
			end
			local st = view.stats
			section(right, "Estatísticas", 1)
			local rows = {
				{ "Patrimônio líquido", "₵ " .. Format.int(view.wealth.netWorth) },
				{ "Saldo / pendente no banco", "₵ " .. Format.int(view.credits) .. " / ₵ " .. Format.int(view.wealth.pending or 0) },
				{ "Valor dos equipamentos", "₵ " .. Format.int(view.wealth.equipValue) },
				{ "Renda do banco", Format.rate(view.bank.rate) },
				{ "Nível", view.level .. (view.rebirths > 0 and (" • ♻️" .. view.rebirths) or "") },
				{ "Skins possuídas", #view.items .. " / " .. view.inventoryCapacity },
				{ "Skins descobertas", found .. " / 60" },
				{ "Caixas abertas", Format.int(st.casesOpened) },
				{ "Skins vendidas", Format.int(st.skinsSold) },
				{ "Melhorias feitas", Format.int(st.upgradesDone) },
				{ "Melhor drop", "₵ " .. Format.int(st.bestDropValue) },
			}
			for i, r in ipairs(rows) do
				local f = UI.frame({ BackgroundColor3 = UI.Theme.panel2, Size = UDim2.new(1, -8, 0, 30), LayoutOrder = 1 + i, Parent = right })
				UI.corner(f, 8)
				UI.text({ Text = r[1], TextSize = 12, TextColor3 = UI.Theme.muted, Size = UDim2.new(0.55, 0, 1, 0), Position = UDim2.fromOffset(10, 0), Parent = f })
				UI.text({ Text = r[2], TextSize = 13, Font = UI.Fonts.bold, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.45, -20, 1, 0), Position = UDim2.new(0.55, 0, 0, 0), Parent = f })
			end

			-- configurações
			section(right, "Configurações", 40)
			local function toggle(order, label, on, action)
				local b = UI.button({
					Text = label .. ": " .. (on and "LIGADO" or "desligado"),
					TextSize = 14,
					color = on and UI.Theme.good or UI.Theme.panel2,
					Size = UDim2.new(1, -8, 0, 38),
					LayoutOrder = order,
					Parent = right,
					onClick = function()
						UI.handle(Net.call("InventoryAction", { action = action, value = not on }))
					end,
				})
				return b
			end
			toggle(41, "⚡ Abertura rápida", view.settings.fastOpen == true, "setFastOpen")
			toggle(42, "🌙 Reduzir efeitos visuais", view.settings.reduceEffects == true, "setReduceEffects")

			-- títulos
			section(right, "Títulos", 60)
			local ids = {}
			for id in pairs(ProgressionConfig.Titles) do
				table.insert(ids, id)
			end
			table.sort(ids, function(a, b)
				local la = ProgressionConfig.Titles[a].level or 1000
				local lb = ProgressionConfig.Titles[b].level or 1000
				if la ~= lb then
					return la < lb
				end
				return a < b
			end)
			for i, id in ipairs(ids) do
				local t = ProgressionConfig.Titles[id]
				local owned = view.titles[id] == true
				local hint = t.level and (" (nível " .. t.level .. ")") or ""
				local btn = UI.button({
					Text = (view.equippedTitle == id and "✔ " or "") .. t.displayName .. (owned and "" or ("  🔒" .. hint)),
					TextSize = 13,
					color = view.equippedTitle == id and UI.Theme.accent or UI.Theme.panel2,
					Size = UDim2.new(1, -8, 0, 34),
					LayoutOrder = 60 + i,
					Parent = right,
					onClick = function()
						UI.handle(Net.call("ProgressionAction", { action = "setTitle", titleId = id }))
					end,
				})
				UI.setEnabled(btn, owned, view.equippedTitle == id and UI.Theme.accent or UI.Theme.panel2)
			end
		end,
	}
end

---------------------------------------------------------------------------
-- Renascimento
---------------------------------------------------------------------------

local function buildRebirth()
	local p = UI.createPanel("♻️ Renascimento", 820, 580)
	local body = UI.scroll({ Size = UDim2.fromScale(1, 1), Parent = p.content })
	UI.list(body, 10)
	return {
		frame = p.frame,
		refresh = function(view)
			UI.clear(body)
			local r = view.rebirth
			local R = ProgressionConfig.Rebirth
			section(body, r.maxed and "Renascimentos máximos alcançados" or ("Renascimento " .. r.next .. " de " .. R.MaxRebirths), 1)
			UI.text({
				Text = "Requisitos: nível <b>" .. r.requiredLevel .. "</b> (você: " .. r.level .. ") e patrimônio <b>₵ " .. Format.int(r.requiredNetWorth) .. "</b> (você: ₵ " .. Format.int(r.netWorth) .. ")",
				TextSize = 15,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, -8, 0, 0),
				LayoutOrder = 2,
				Parent = body,
			})
			local keep = UI.frame({ BackgroundColor3 = UI.Theme.good:Lerp(UI.Theme.panel, 0.75), AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -8, 0, 0), LayoutOrder = 3, Parent = body })
			UI.corner(keep, 10)
			UI.padding(keep, 12)
			UI.text({
				Text = "<b>SERÁ MANTIDO</b>\n• " .. r.keepItems.count .. " skin(s) Raras ou superiores e todas as favoritas (₵ " .. Format.int(r.keepItems.value) .. ") — nada raro é apagado\n• Índice, coleções concluídas, cosméticos e recompensas resgatadas\n• Conquistas, títulos, materiais, caixas grátis e atributos\n• Missões em andamento",
				TextSize = 14,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				Parent = keep,
			})
			local lose = UI.frame({ BackgroundColor3 = UI.Theme.bad:Lerp(UI.Theme.panel, 0.7), AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -8, 0, 0), LayoutOrder = 4, Parent = body })
			UI.corner(lose, 10)
			UI.padding(lose, 12)
			UI.text({
				Text = "<b>SERÁ REINICIADO</b>\n• " .. r.loseItems.count .. " skin(s) Comuns/Incomuns não favoritadas (₵ " .. Format.int(r.loseItems.value) .. ")\n• Saldo de ₵ " .. Format.int(r.creditsLost) .. " volta para ₵ " .. Format.int(r.creditsAfter) .. "\n• Créditos pendentes do banco (₵ " .. Format.int(r.pendingBankLost) .. ") e melhorias do banco\n• Nível e XP voltam ao nível 1",
				TextSize = 14,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				Parent = lose,
			})
			UI.text({
				Text = "<b>Benefícios permanentes após renascer:</b> +" .. Format.percent(r.bankEfficiencyAfter, 0) .. " de renda no banco, +" .. Format.percent(r.luckAfter, 0) .. " de sorte, +" .. Format.percent(r.xpBonusAfter, 0) .. " de XP, +" .. r.bankSlotBonusAfter .. " vaga(s) de banco, +" .. r.equipSlotBonusAfter .. " vaga(s) de exibição e títulos exclusivos.",
				TextSize = 14,
				TextColor3 = UI.Theme.accent,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, -8, 0, 0),
				LayoutOrder = 5,
				Parent = body,
			})
			local btn = UI.button({
				Text = "♻️ Renascer",
				Font = UI.Fonts.title,
				TextSize = 22,
				color = UI.Theme.bad,
				Size = UDim2.fromOffset(260, 52),
				LayoutOrder = 6,
				Parent = body,
				onClick = function()
					UI.confirm({
						title = "Confirmar renascimento",
						message = "Você perderá " .. r.loseItems.count .. " skin(s), o saldo, o nível e as melhorias do banco, conforme listado. Esta ação NÃO pode ser desfeita.\n\nDigite " .. r.confirmPhrase .. " para confirmar.",
						confirmText = "Renascer",
						danger = true,
						phrase = r.confirmPhrase,
						onConfirm = function(typed)
							local res = Net.call("ProgressionAction", { action = "rebirth", confirmPhrase = typed })
							UI.handle(res, "Você renasceu! Renascimentos: " .. (res.ok and res.data.rebirths or ""))
						end,
					})
				end,
			})
			UI.setEnabled(btn, r.canRebirth, UI.Theme.bad)
		end,
	}
end

function Panels.init()
	UI.register("Missions", buildMissions)
	UI.register("Gifts", buildGifts)
	UI.register("Luck", buildLuck)
	UI.register("Attributes", buildAttributes)
	UI.register("Rebirth", buildRebirth)
end

return Panels
