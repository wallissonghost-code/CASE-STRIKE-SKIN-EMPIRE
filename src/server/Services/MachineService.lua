-- Uso das máquinas misteriosas. Fluxo no SERVIDOR:
-- 1. confere perfil, intervalo mínimo entre aberturas e se o jogador está perto da máquina;
-- 2. ProfileOps.useMachine confere nível, saldo e espaço, desconta o preço, sorteia com o Random
--    do servidor, entrega o objeto, registra descoberta, XP e missões — tudo de uma vez;
-- 3. avisa todos os clientes (MachineResult) para tocarem a animação daquela máquina.
-- O cliente só envia o id da máquina; preço, chances e resultado nunca vêm dele.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared.EconomyConfig)
local MachineDefinitions = require(Shared.MachineDefinitions)
local ItemDefinitions = require(Shared.ItemDefinitions)
local RarityConfig = require(Shared.RarityConfig)
local ProfileOps = require(Shared.Logic.ProfileOps)
local TimeUtil = require(Shared.Util.TimeUtil)
local Remotes = require(script.Parent.Parent.Core.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local MapService = require(script.Parent.MapService)

local MachineService = {}

MachineService.rng = Random.new()
local lastOpen = {} -- [player] = os.clock()

local function nearMachine(player, machineId)
	local pos = MapService.machinePosition(machineId)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not pos or not root then
		return false
	end
	return (root.Position - pos).Magnitude <= MachineDefinitions.UseRadius
end

function MachineService.use(player, profile, payload)
	local machineId = payload.machineId
	if not MachineDefinitions.get(machineId) then
		return { ok = false, error = "unknown", message = "Máquina desconhecida." }
	end
	local last = lastOpen[player]
	if last and os.clock() - last < EconomyConfig.OpenCooldown then
		return { ok = false, error = "busy", message = "A máquina ainda está entregando o prêmio." }
	end
	if not nearMachine(player, machineId) then
		return { ok = false, error = "far", message = "Chegue perto da máquina para usá-la." }
	end
	local result = ProfileOps.useMachine(profile, machineId, MachineService.rng:NextNumber(), TimeUtil.now())
	if not result.ok then
		return result
	end
	lastOpen[player] = os.clock()
	Remotes.event("MachineResult"):FireAllClients({
		machineId = machineId,
		userId = player.UserId,
		itemId = result.itemId,
		rarity = result.rarity,
		duration = result.duration,
	})
	local rarity = RarityConfig.get(result.rarity)
	if rarity.announce then
		local item = ItemDefinitions.get(result.itemId)
		Remotes.notifyAll((rarity.effect == "secret" and "🔴 " or "🌟 ") .. player.DisplayName .. " conseguiu " .. item.name .. " (" .. rarity.name .. ")!", rarity.effect)
	end
	return result
end

function MachineService.start()
	Remotes.handle("RequestMachineUse", "use", "machine", MachineService.use)
	PlayerDataService.onLeaving(function(player)
		lastOpen[player] = nil
	end)
end

return MachineService
