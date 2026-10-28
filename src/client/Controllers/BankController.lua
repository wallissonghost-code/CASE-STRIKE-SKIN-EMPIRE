-- BankController: banco de skins (vagas, renda por skin, renda total, acumulado, resgate e melhorias).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local RarityConfig = require(Shared.Config.RarityConfig)
local BankMath = require(Shared.Logic.BankMath)

local UI = require(script.Parent.UIController)
local Net = require(script.Parent.Parent.Util.Net)
local Store = require(script.Parent.Parent.Util.Store)

local Bank = {}

local function build()
	local p = UI.createPanel("🏦 Banco de Skins", 1080, 620)

	-- resumo
	local summary = UI.frame({ BackgroundColor3 = UI.Theme.panel2, BackgroundTransparency = 0.2, Size = UDim2.new(1, 0, 0, 96), Parent = p.content })
	UI.corner(summary, 12)
	local slotsL = UI.text({ Font = UI.Fonts.bold, TextSize = 15, Size = UDim2.fromOffset(240, 22), Position = UDim2.fromOffset(16, 12), Parent = summary })
	local rateL = UI.text({ Font = UI.Fonts.bold, TextSize = 15, TextColor3 = UI.Theme.good, Size = UDim2.fromOffset(300, 22), Position = UDim2.fromOffset(16, 38), Parent = summary })
	local infoL = UI.text({ TextSize = 12, TextColor3 = UI.Theme.muted, Size = UDim2.fromOffset(420, 32), Position = UDim2.fromOffset(16, 60), Parent = summary })
	local pendingL = UI.text({ Font = UI.Fonts.title, TextSize = 30, TextColor3 = UI.Theme.accent, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(300, 36), Position = UDim2.new(1, -520, 0, 14), Parent = summary })
	local capL = UI.text({ TextSize = 13, TextColor3 = UI.Theme.muted, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(300, 18), Position = UDim2.new(1, -520, 0, 52), Parent = summary })
	local capBack = UI.frame({ BackgroundColor3 = UI.Theme.bg, Size = UDim2.fromOffset(300, 8), Position = UDim2.new(1, -520, 0, 74), Parent = summary })
	UI.corner(capBack, 4)
	local capFill = UI.frame({ BackgroundColor3 = UI.Theme.accent, Size = UDim2.fromScale(0, 1), Parent = capBack })
	UI.corner(capFill, 4)
	UI.button({
		Text = "Resgatar créditos",
		color = UI.Theme.good,
		Font = UI.Fonts.title,
		TextSize = 20,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(190, 56),
		Parent = summary,
		onClick = function()
			local res = Net.call("BankAction", { action = "claim" })
			if res.ok then
				UI.toast("Resgatado: ₵ " .. Format.int(res.data.credits), "good")
			else
				UI.handle(res)
			end
		end,
	})

	-- colunas
	local colW = 340
	local function column(title, x)
		UI.text({ Text = title, Font = UI.Fonts.bold, TextSize = 15, Size = UDim2.fromOffset(colW, 20), Position = UDim2.fromOffset(x, 106), Parent = p.content })
		local s = UI.scroll({ Size = UDim2.new(0, colW, 1, -132), Position = UDim2.fromOffset(x, 130), Parent = p.content })
		UI.list(s, 6)
		return s
	end
	local depositedList = column("Skins depositadas", 0)
	local candidateList = column("Depositar (maior renda primeiro)", colW + 14)
	local upgradeList = column("Melhorias do banco", (colW + 14) * 2)

	local function skinRow(parent, item, def, rightText, buttonText, buttonColor, onClick, order)
		local f = UI.frame({ BackgroundColor3 = UI.Theme.panel2, Size = UDim2.new(1, -8, 0, 58), LayoutOrder = order, Parent = parent })
		UI.corner(f, 10)
		UI.stroke(f, UI.rarityColor(def.rarity), 1.5, 0.4)
		local slot = UI.frame({ BackgroundTransparency = 1, Size = UDim2.fromOffset(70, 54), Position = UDim2.fromOffset(4, 2), Parent = f })
		UI.skinViewport(def, item.upgrades, UDim2.fromScale(1, 1), {}).Parent = slot
		UI.text({ Text = def.name, Font = UI.Fonts.bold, TextSize = 12, Size = UDim2.new(1, -190, 0, 30), Position = UDim2.fromOffset(78, 4), Parent = f })
		UI.text({ Text = rightText, TextSize = 12, TextColor3 = UI.Theme.good, Size = UDim2.new(1, -190, 0, 18), Position = UDim2.fromOffset(78, 34), Parent = f })
		UI.button({ Text = buttonText, TextSize = 13, color = buttonColor, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(100, 36), Parent = f, onClick = onClick })
	end

	local function refresh(view)
		local b = view.bank
		local used = 0
		for _, item in ipairs(view.items) do
			if item.location == "bank" then
				used = used + 1
			end
		end
		slotsL.Text = "Vagas: " .. used .. " / " .. b.slots
		rateL.Text = "Renda total: " .. Format.rate(b.rate) .. "  (₵ " .. Format.short(b.rate * 3600) .. "/h)"
		infoL.Text = "Eficiência ×" .. string.gsub(string.format("%.2f", b.efficiency), "%.", ",") .. " • produção offline máxima: " .. Format.duration(b.maxOfflineSeconds) .. " • apenas créditos do jogo"
		capL.Text = "Cofre: máx. ₵ " .. Format.int(b.storageCap)

		UI.clear(depositedList)
		local order = 0
		for _, item in ipairs(view.items) do
			if item.location == "bank" then
				order = order + 1
				local def = SkinDefinitions.ById[item.defId]
				skinRow(depositedList, item, def, "+" .. Format.rate(item.income), "Retirar", UI.Theme.panel, function()
					UI.handle(Net.call("BankAction", { action = "withdraw", uid = item.uid }))
				end, order)
			end
		end
		if order == 0 then
			UI.text({ Text = "Nenhuma skin depositada. Deposite skins para gerar renda passiva.", TextColor3 = UI.Theme.muted, TextSize = 13, Size = UDim2.new(1, 0, 0, 40), Parent = depositedList })
		end

		UI.clear(candidateList)
		local candidates = {}
		for _, item in ipairs(view.items) do
			if item.location == "inventory" then
				table.insert(candidates, item)
			end
		end
		table.sort(candidates, function(a, c)
			return SkinDefinitions.ById[a.defId].value > SkinDefinitions.ById[c.defId].value
		end)
		for i = 1, math.min(25, #candidates) do
			local item = candidates[i]
			local def = SkinDefinitions.ById[item.defId]
			local income = BankMath.baseIncome(def) * b.efficiency
			skinRow(candidateList, item, def, "renderia " .. Format.rate(income), used < b.slots and "Depositar" or "Sem vaga", used < b.slots and UI.Theme.good or UI.Theme.locked, function()
				UI.handle(Net.call("BankAction", { action = "deposit", uid = item.uid }), "Skin depositada.")
			end, i)
		end

		UI.clear(upgradeList)
		for i, u in ipairs(b.upgrades) do
			local f = UI.frame({ BackgroundColor3 = UI.Theme.panel2, Size = UDim2.new(1, -8, 0, 86), LayoutOrder = i, Parent = upgradeList })
			UI.corner(f, 10)
			UI.text({ Text = u.displayName .. "  <font color='#A5AABE'>(" .. u.level .. "/" .. u.maxLevel .. ")</font>", Font = UI.Fonts.bold, TextSize = 15, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 6), Parent = f })
			UI.text({ Text = u.description, TextSize = 12, TextColor3 = UI.Theme.muted, Size = UDim2.new(1, -130, 0, 18), Position = UDim2.fromOffset(10, 30), Parent = f })
			local maxed = u.level >= u.maxLevel
			local req = (not maxed) and u.requiredLevel or 0
			local lockedByLevel = (not maxed) and view.level < req
			UI.text({
				Text = maxed and "Nível máximo" or (("₵ " .. Format.int(u.cost)) .. (lockedByLevel and ("  • requer nível " .. req) or "")),
				TextSize = 13,
				Font = UI.Fonts.bold,
				TextColor3 = lockedByLevel and UI.Theme.bad or UI.Theme.accent,
				Size = UDim2.new(1, -130, 0, 18),
				Position = UDim2.fromOffset(10, 56),
				Parent = f,
			})
			local btn = UI.button({
				Text = maxed and "✔" or "Melhorar",
				color = UI.Theme.blue,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(110, 40),
				Parent = f,
				onClick = function()
					UI.handle(Net.call("BankAction", { action = "upgrade", upgradeId = u.id }), "Melhoria comprada!")
				end,
			})
			UI.setEnabled(btn, (not maxed) and (not lockedByLevel) and view.credits >= (u.cost or math.huge), UI.Theme.blue)
		end
	end

	-- contador ao vivo do acumulado (apenas exibição; o servidor calcula o valor real)
	task.spawn(function()
		while true do
			if p.frame.Visible and Store.view then
				local pending = Store.bankPendingLive()
				pendingL.Text = "₵ " .. Format.int(math.floor(pending))
				capFill.Size = UDim2.fromScale(math.clamp(pending / math.max(1, Store.view.bank.storageCap), 0, 1), 1)
			end
			task.wait(0.25)
		end
	end)

	return { frame = p.frame, refresh = refresh }
end

function Bank.init()
	UI.register("Bank", build)
end

return Bank
