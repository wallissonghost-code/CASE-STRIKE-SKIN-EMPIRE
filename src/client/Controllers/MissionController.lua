-- Missões: presente diário, 3 missões do dia (com progresso) e conquistas permanentes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared.EconomyConfig)
local Format = require(Shared.Util.Format)

local UI = require(script.Parent.Parent.Util.UI)
local Store = require(script.Parent.Parent.Util.Store)
local Net = require(script.Parent.Parent.Util.Net)
local UIController = require(script.Parent.UIController)

local MissionController = {}

local ui = { daily = {}, achievements = {} }
local tab = "daily"

local function rewardToast(r)
	local text = "🎁 +" .. Format.int(r.coins) .. " Coins"
	if (r.xp or 0) > 0 then
		text = text .. "  +" .. r.xp .. " XP"
	end
	UIController.toast(text, "coins")
end

local function claim(payload)
	local r = Net.call("ProgressAction", payload)
	if r.ok then
		rewardToast(r)
	else
		UIController.toast(r.message, "warn")
	end
	return r
end

local function missionRow(parent, order)
	local row = {}
	row.frame = UI.frame(parent, { Size = UDim2.new(1, -12, 0, 70), LayoutOrder = order })
	row.text = UI.label(row.frame, "", { Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -220, 0, 26), MaxText = 19 })
	local _, set = UI.progress(row.frame, { Position = UDim2.new(0, 12, 0, 38), Size = UDim2.new(1, -380, 0, 22) })
	row.setProgress = set
	row.reward = UI.label(row.frame, "", { Position = UDim2.new(1, -360, 0, 38), Size = UDim2.new(0, 150, 0, 22), TextColor3 = UI.Theme.coins, MaxText = 15 })
	row.button = UI.button(row.frame, "RESGATAR", UI.Theme.green, nil, { Position = UDim2.new(1, -196, 0.5, -22), Size = UDim2.new(0, 184, 0, 44), MaxText = 18 })
	return row
end

local function fillRow(row, m, fmtProgress)
	row.text.Text = m.text
	local label = fmtProgress and fmtProgress(m) or (Format.int(m.progress) .. "/" .. Format.int(m.target))
	row.setProgress(m.progress / m.target, label)
	row.reward.Text = "💰" .. Format.short(m.coins) .. ((m.xp or 0) > 0 and ("  ⭐" .. m.xp) or "")
	if m.claimed then
		row.button.Text = "✔ Feito"
		UI.setEnabled(row.button, false)
	elseif m.progress >= m.target then
		row.button.Text = "RESGATAR"
		UI.setEnabled(row.button, true, UI.Theme.green)
	else
		row.button.Text = "Em andamento"
		UI.setEnabled(row.button, false)
	end
end

function MissionController.refresh(view)
	if not ui.dailyPage then
		return
	end
	ui.dailyPage.Visible = tab == "daily"
	ui.achPage.Visible = tab == "achievements"
	local g = view.gift
	if g.canClaim then
		ui.giftText.Text = "🎁 Presente diário — dia " .. g.nextStreak .. "/" .. #EconomyConfig.DailyGift.coins .. ": 💰" .. Format.int(g.coins) .. " + " .. g.xp .. " XP"
		ui.giftButton.Text = "RESGATAR"
		UI.setEnabled(ui.giftButton, true, UI.Theme.green)
	else
		ui.giftText.Text = "🎁 Presente resgatado (sequência " .. g.streak .. "). Próximo em " .. Format.duration(g.secondsLeft)
		ui.giftButton.Text = "✔ Amanhã"
		UI.setEnabled(ui.giftButton, false)
	end
	for i, row in ipairs(ui.daily) do
		local m = view.daily[i]
		row.frame.Visible = m ~= nil
		if m then
			row.id = m.id
			fillRow(row, m, m.id == "d_play" and function(x)
				return math.floor(x.progress / 60) .. "/" .. math.floor(x.target / 60) .. " min"
			end or nil)
		end
	end
	ui.dailyFooter.Text = "Novas missões em " .. Format.duration(g.secondsLeft) .. "  •  Moedas perdidas restantes nesta hora: " .. view.pickupsLeft
	for i, row in ipairs(ui.achievements) do
		local m = view.achievements[i]
		row.frame.Visible = m ~= nil
		if m then
			row.id = m.id
			fillRow(row, m)
		end
	end
end

local function build(content)
	local selectTab = UI.tabs(content, { { id = "daily", label = "📅 Diárias", width = 160 }, { id = "achievements", label = "🏅 Conquistas", width = 180 } }, function(id)
		tab = id
		if Store.view then
			MissionController.refresh(Store.view)
		end
	end)
	ui.dailyPage = UI.make("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(1, 0, 1, -46), Parent = content })
	local gift = UI.frame(ui.dailyPage, { Size = UDim2.new(1, -12, 0, 64), BackgroundColor3 = Color3.fromRGB(90, 60, 130) })
	ui.giftText = UI.label(gift, "", { Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -220, 1, 0), TextWrapped = true, MaxText = 19 })
	ui.giftButton = UI.button(gift, "RESGATAR", UI.Theme.green, function(b)
		if not b:GetAttribute("Disabled") then
			claim({ action = "claimGift" })
		end
	end, { Name = "Gift", Position = UDim2.new(1, -196, 0.5, -22), Size = UDim2.new(0, 184, 0, 44), MaxText = 18 })
	local list = UI.make("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 74), Size = UDim2.new(1, 0, 1, -110), Parent = ui.dailyPage })
	UI.list(list, 8)
	for i = 1, 3 do
		local row = missionRow(list, i)
		row.button.Activated:Connect(function()
			if row.id and not row.button:GetAttribute("Disabled") then
				claim({ action = "claimDaily", missionId = row.id })
			end
		end)
		ui.daily[i] = row
	end
	ui.dailyFooter = UI.label(ui.dailyPage, "", { Position = UDim2.new(0, 0, 1, -28), Size = UDim2.new(1, 0, 0, 24), TextColor3 = UI.Theme.muted, MaxText = 16 })

	ui.achPage = UI.scroll(content, { Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(1, 0, 1, -46), Visible = false })
	UI.list(ui.achPage, 8)
	local MissionDefinitions = require(Shared.MissionDefinitions)
	for i = 1, #MissionDefinitions.Achievements do
		local row = missionRow(ui.achPage, i)
		row.button.Activated:Connect(function()
			if row.id and not row.button:GetAttribute("Disabled") then
				claim({ action = "claimAchievement", achievementId = row.id })
			end
		end)
		ui.achievements[i] = row
	end
	ui.selectTab = selectTab
	selectTab("daily")
end

function MissionController.init()
	UIController.register("Missions", {
		screen = "MissionUI",
		title = "📜 Missões e Presentes",
		build = build,
		refresh = MissionController.refresh,
		onOpen = function(args)
			if args.tab and ui.selectTab then
				ui.selectTab(args.tab)
			end
		end,
	})
end

return MissionController
