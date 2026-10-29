-- BaseController: painel da Base — criaturas nos pedestais (renda, guardado, valor, vender)
-- e melhorias (pedestais, cofre, escudo, velocidade).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)

local UI = require(script.Parent.UIController)
local Net = require(script.Parent.Parent.Util.Net)
local Store = require(script.Parent.Parent.Util.Store)

local Base = {}

local function sell(c)
	local s = GameConfig.SpeciesById[c.speciesId]
	local valuable = GameConfig.tier(s.rarity) >= GameConfig.ValuableConfirmTier
	local function doSell()
		local res = Net.call("BaseAction", { action = "sell", uid = c.uid, confirm = valuable })
		UI.handle(res, res.ok and ("Vendida por $" .. Format.short(res.data.coins + res.data.collected)) or nil)
	end
	if valuable then
		UI.confirm({
			title = "Vender criatura valiosa?",
			message = "Vender " .. UI.creatureName(c.speciesId, c.mutationId) .. " por $" .. Format.short(c.sellPrice) .. " (50% do valor) + o que estiver guardado. Não dá para desfazer.",
			confirmText = "Vender",
			danger = true,
			onConfirm = doSell,
		})
	else
		doSell()
	end
end

local function build()
	local p = UI.createPanel("🏠 Minha base", 900, 580, "BaseManager")
	local summary = UI.text({ Text = "", TextSize = 15, Size = UDim2.new(1, 0, 0, 44), Parent = p.content })
	local left = UI.scroll({ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(0.6, -8, 1, -50), Parent = p.content })
	UI.list(left, 6)
	local right = UI.scroll({ Position = UDim2.new(0.6, 8, 0, 50), Size = UDim2.new(0.4, -8, 1, -50), Parent = p.content })
	UI.list(right, 8)

	local function refresh(view)
		summary.Text = string.format(
			"Renda: <font color='#7CFF8A'>+$%s/s</font>  •  Guardado: <font color='#FFD84A'>$%s</font>  •  Pedestais: %d/%d  •  Cofre: %s por criatura  •  Escudo: %ds",
			Format.short(view.rate * (view.boost or 1)),
			Format.short(Store.pendingLive()),
			#view.creatures,
			view.slots,
			Format.duration(view.storageSeconds),
			view.shieldSeconds
		) .. "\n<font color='#9FB5A8'>Colete no terminal amarelo da base (ou no botão COLETAR estando dentro dela).</font>"
		UI.clear(left)
		if #view.creatures == 0 then
			UI.text({ Text = "Sua base está vazia. Compre criaturas na esteira da praça ou abra ovos nos quiosques!", TextSize = 16, TextColor3 = UI.Theme.muted, Size = UDim2.new(1, -8, 0, 60), Parent = left })
		end
		for i, c in ipairs(view.creatures) do
			local s = GameConfig.SpeciesById[c.speciesId]
			local row = UI.frame({ Size = UDim2.new(1, -8, 0, 64), LayoutOrder = i, Parent = left })
			UI.corner(row, 10)
			UI.stroke(row, UI.rarityColor(s.rarity), 2, 0.4)
			local vp = UI.creatureViewport(c.speciesId, c.mutationId, UDim2.fromOffset(60, 60))
			vp.Position = UDim2.fromOffset(2, 2)
			vp.Parent = row
			local protected = (c.protectedUntil or 0) > Store.serverNow()
			UI.text({ Text = "#" .. c.pad .. "  " .. UI.creatureName(c.speciesId, c.mutationId, true) .. (protected and "  🛡️" or ""), Font = UI.Fonts.bold, TextSize = 16, Size = UDim2.new(1, -200, 0, 24), Position = UDim2.fromOffset(68, 6), Parent = row })
			UI.text({ Text = "+$" .. Format.short(c.rate) .. "/s  •  guardado $" .. Format.short(c.pending) .. "  •  valor $" .. Format.short(c.value), TextSize = 13, TextColor3 = UI.Theme.muted, Size = UDim2.new(1, -200, 0, 22), Position = UDim2.fromOffset(68, 32), Parent = row })
			UI.button({ Text = "Vender $" .. Format.short(c.sellPrice), TextSize = 14, color = UI.Theme.bad, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(120, 40), Parent = row, onClick = function()
				sell(c)
			end })
		end
		UI.clear(right)
		UI.text({ Text = "Melhorias", Font = UI.Fonts.title, TextSize = 22, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 0, Parent = right })
		for i, u in ipairs(view.upgrades) do
			local row = UI.frame({ Size = UDim2.new(1, -8, 0, 96), LayoutOrder = i, Parent = right })
			UI.corner(row, 10)
			UI.text({ Text = "<b>" .. u.name .. "</b>  " .. u.level .. "/" .. u.maxLevel, TextSize = 16, Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(10, 6), Parent = row })
			UI.text({ Text = u.description, TextSize = 13, TextColor3 = UI.Theme.muted, Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(10, 28), Parent = row })
			local maxed = u.cost == nil
			local b = UI.button({
				Text = maxed and "MÁXIMO" or (u.name .. " • $" .. Format.short(u.cost)),
				TextSize = 14,
				color = UI.Theme.accent,
				Position = UDim2.fromOffset(10, 52),
				Size = UDim2.new(1, -20, 0, 36),
				Parent = row,
				onClick = function()
					UI.handle(Net.call("BaseAction", { action = "upgrade", upgradeId = u.id }), u.name .. " melhorado!")
				end,
			})
			UI.setEnabled(b, not maxed and view.coins >= (u.cost or 0), UI.Theme.accent)
		end
	end
	return { frame = p.frame, refresh = refresh }
end

function Base.init()
	UI.register("Base", build)
end

return Base
