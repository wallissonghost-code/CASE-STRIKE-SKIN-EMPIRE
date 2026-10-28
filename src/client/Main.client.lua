-- Ponto de entrada do cliente. O cliente cuida apenas de apresentação, animações e entrada;
-- saldo, itens, probabilidades e persistência são decididos pelo servidor.

local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local Controllers = script.Parent:WaitForChild("Controllers")
local Util = script.Parent:WaitForChild("Util")

local UI = require(Controllers.UIController)
local Store = require(Util.Store)
local Net = require(Util.Net)

UI.init()
UI.store = Store
Net.setBusyHandler(function(on)
	UI.setLoading(on)
end)

local order = {
	"HUDController",
	"CaseController",
	"ShopController",
	"InventoryController",
	"BankController",
	"UpgradeController",
	"CollectionController",
	"ProgressionPanels",
	"LeaderboardController",
	"LobbyController",
}
for _, name in ipairs(order) do
	require(Controllers:WaitForChild(name)).init()
end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) -- sem ferramentas/armas
end)

-- avisos de progresso comparando fotografias
local last = nil
Store.changed:Connect(function(view)
	UI.refreshCurrent(view)
	if last then
		if view.level > last.level and view.rebirths == last.rebirths then
			UI.toast("⬆️ Nível " .. view.level .. "!", "good")
		end
		local before = {}
		for _, a in ipairs(last.achievements) do
			before[a.id] = a.unlocked
		end
		for _, a in ipairs(view.achievements) do
			if a.unlocked and not before[a.id] then
				UI.toast("🏅 Conquista desbloqueada! Resgate em Presentes.", "rare")
			end
		end
	end
	last = view
end)

Store.init()

-- tela de carregamento simples até a primeira fotografia
local loading = UI.text({
	Text = "Carregando seu império de skins...",
	Font = UI.Fonts.title,
	TextSize = 28,
	TextXAlignment = Enum.TextXAlignment.Center,
	BackgroundTransparency = 0.2,
	BackgroundColor3 = UI.Theme.bg,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 100,
	Parent = UI.layers.Modal,
})
task.spawn(function()
	while not Store.view do
		task.wait(0.2)
	end
	loading:Destroy()
end)

-- Esc / botão voltar do controle fecha o painel aberto
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		UI.close()
	end
end)
