-- MYSTERY MACHINE — Máquina Surpresa: inicialização do servidor.
-- Ordem: mapa → remotes → dados → serviços de jogo. Nenhum serviço confia em valores do cliente.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileOps = require(Shared.Logic.ProfileOps)
local MachineDefinitions = require(Shared.MachineDefinitions)

local Core = script.Parent.Core
local Services = script.Parent.Services
local Remotes = require(Core.Remotes)
local MapService = require(Services.MapService)
local PlayerDataService = require(Services.PlayerDataService)
local EconomyService = require(Services.EconomyService)
local MachineService = require(Services.MachineService)
local InventoryService = require(Services.InventoryService)
local UpgradeService = require(Services.UpgradeService)
local CollectionService = require(Services.CollectionService)
local MissionService = require(Services.MissionService)
local RewardService = require(Services.RewardService)
local ShowcaseService = require(Services.ShowcaseService)
local LeaderboardService = require(Services.LeaderboardService)

MapService.build()
Remotes.init(PlayerDataService)

-- ações gerais: sincronizar (o cliente pede a fotografia ao iniciar), configurações do jogador e atalhos de teleporte do menu
Remotes.handle("ProgressAction", "sync", "progress", function()
	return { ok = true }
end)
Remotes.handle("ProgressAction", "setSetting", "progress", function(_, profile, payload)
	return ProfileOps.setSetting(profile, payload.key, payload.value)
end)
Remotes.handle("ProgressAction", "goto", "progress", function(player, _, payload)
	local target = payload.target
	local point
	if MachineDefinitions.get(target) then
		point = MapService.machines[target].standPoint
	elseif target == "showcase" then
		point = ShowcaseService.boothPosition(player) or MapService.points.gallery
	elseif type(target) == "string" then
		point = MapService.points[target]
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not point or not root then
		return { ok = false, error = "invalid", message = "Destino indisponível." }
	end
	root.CFrame = CFrame.new(point)
	return { ok = true }
end)

MachineService.start()
InventoryService.start()
UpgradeService.start()
CollectionService.start()
MissionService.start()
RewardService.start()
ShowcaseService.start()
EconomyService.start()
LeaderboardService.start()
PlayerDataService.start()

print("[MYSTERY MACHINE] servidor pronto")
