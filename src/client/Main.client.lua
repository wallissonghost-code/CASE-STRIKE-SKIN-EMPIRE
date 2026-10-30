-- MYSTERY MACHINE — Máquina Surpresa: inicialização do cliente.
-- O cliente só desenha e envia pedidos; o servidor decide tudo.

local Controllers = script.Parent.Controllers
local Util = script.Parent.Util

local Store = require(Util.Store)
local Net = require(Util.Net)
local UIController = require(Controllers.UIController)
local HUDController = require(Controllers.HUDController)
local MachineController = require(Controllers.MachineController)
local InventoryController = require(Controllers.InventoryController)
local CollectionController = require(Controllers.CollectionController)
local UpgradeController = require(Controllers.UpgradeController)
local MissionController = require(Controllers.MissionController)
local LeaderboardController = require(Controllers.LeaderboardController)
local SettingsController = require(Controllers.SettingsController)

Net.on("DataUpdated", function(view)
	if type(view) == "table" then
		Store.set(view)
	end
end)

UIController.init()
HUDController.init()
MachineController.init()
InventoryController.init()
CollectionController.init()
UpgradeController.init()
MissionController.init()
LeaderboardController.init()
SettingsController.init()

-- pede a fotografia atual (caso o envio inicial do servidor tenha chegado antes do cliente)
task.spawn(function()
	while not Store.view do
		Net.call("ProgressAction", { action = "sync" })
		task.wait(2)
	end
end)
