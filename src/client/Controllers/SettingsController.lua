-- Configurações (salvas no perfil pelo servidor) e atalhos para os lugares do parque.

local UI = require(script.Parent.Parent.Util.UI)
local Net = require(script.Parent.Parent.Util.Net)
local UIController = require(script.Parent.UIController)

local SettingsController = {}

SettingsController.Options = {
	{ key = "autoSkip", label = "Pular animação automaticamente" },
	{ key = "sound", label = "Sons" },
	{ key = "effects", label = "Efeitos visuais (brilhos e partículas)" },
}

SettingsController.Places = {
	{ target = "plaza", label = "⛲ Praça" },
	{ target = "common", label = "🎰 Máquinas" },
	{ target = "shop", label = "⚙️ Loja" },
	{ target = "gallery", label = "🏛️ Galeria" },
	{ target = "showcase", label = "🖼️ Minha vitrine" },
	{ target = "ranking", label = "🏆 Ranking" },
}

local toggles = {}

function SettingsController.refresh(view)
	for key, b in pairs(toggles) do
		local on = view.settings[key] == true
		b.Text = on and "LIGADO" or "DESLIGADO"
		b.BackgroundColor3 = on and UI.Theme.green or UI.Theme.grey
	end
end

local function build(content)
	local list = UI.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 200), Parent = content })
	UI.list(list, 8)
	for i, opt in ipairs(SettingsController.Options) do
		local row = UI.frame(list, { Size = UDim2.new(1, 0, 0, 56), LayoutOrder = i })
		UI.label(row, opt.label, { Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -220, 1, 0), MaxText = 20 })
		toggles[opt.key] = UI.button(row, "", UI.Theme.grey, function(b)
			local r = Net.call("ProgressAction", { action = "setSetting", key = opt.key, value = b.Text ~= "LIGADO" })
			if not r.ok then
				UIController.toast(r.message, "warn")
			end
		end, { Name = opt.key, Position = UDim2.new(1, -190, 0.5, -21), Size = UDim2.new(0, 176, 0, 42), MaxText = 18 })
	end
	UI.label(content, "Ir para:", { Position = UDim2.new(0, 0, 0, 200), Size = UDim2.new(1, 0, 0, 28), Font = Enum.Font.FredokaOne, MaxText = 22 })
	local places = UI.make("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 234), Size = UDim2.new(1, 0, 0, 110), Parent = content })
	UI.make("UIGridLayout", { CellSize = UDim2.new(0, 238, 0, 48), CellPadding = UDim2.new(0, 8, 0, 8), Parent = places })
	for _, place in ipairs(SettingsController.Places) do
		UI.button(places, place.label, UI.Theme.blue, function()
			local r = Net.call("ProgressAction", { action = "goto", target = place.target })
			if r.ok then
				UIController.close()
			else
				UIController.toast(r.message, "warn")
			end
		end, { MaxText = 18 })
	end
	UI.label(content, "MYSTERY MACHINE v1.0 — sem compras com Robux, sem apostas. Chances sempre visíveis.", {
		Position = UDim2.new(0, 0, 1, -26),
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = UI.Theme.muted,
		MaxText = 14,
	})
end

function SettingsController.init()
	UIController.register("Settings", {
		screen = "SettingsUI",
		title = "🔧 Configurações",
		build = build,
		refresh = SettingsController.refresh,
	})
end

return SettingsController
