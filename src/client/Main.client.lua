-- Ponto de entrada do cliente do MUTANT FACTORY: interface (somente exibição; o servidor decide tudo).

local Controllers = script.Parent.Controllers
local UI = require(Controllers.UIController)
local Net = require(script.Parent.Util.Net)
local Store = require(script.Parent.Util.Store)

UI.init()
UI.store = Store
Net.setBusyHandler(UI.setLoading)

for _, name in ipairs({ "HUDController", "EggController", "BaseController", "IndexController", "ProgressPanels", "WorldController" }) do
	require(Controllers[name]).init()
end

Store.changed:Connect(function(view)
	UI.refreshCurrent(view)
end)
Store.init()
