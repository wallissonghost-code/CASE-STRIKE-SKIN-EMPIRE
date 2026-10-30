-- Coins: leaderstats e "moedas perdidas" pelo parque (atividade gratuita para quem ficou sem saldo).
-- A coleta é validada no servidor: jogador perto da moeda, perfil carregado e limite por hora.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared.EconomyConfig)
local ProfileOps = require(Shared.Logic.ProfileOps)
local TimeUtil = require(Shared.Util.TimeUtil)
local Remotes = require(script.Parent.Parent.Core.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local MapService = require(script.Parent.MapService)

local EconomyService = {}

local active = {} -- [spotIndex] = part
local limitWarned = {} -- [player] = os.clock() do último aviso de limite
local rng = Random.new()

local function updateLeaderstats(player, profile)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Parent = stats
		local level = Instance.new("IntValue")
		level.Name = "Nível"
		level.Parent = stats
		stats.Parent = player
	end
	stats.Coins.Value = profile.coins
	stats["Nível"].Value = ProfileOps.level(profile)
end

local function playerFromHit(hit)
	local model = hit and hit.Parent
	if not model then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

-- tenta coletar a moeda do ponto `spot` para o jogador (validação completa no servidor)
function EconomyService.collect(player, spot)
	local coin = active[spot]
	if not coin or not coin.Parent then
		return false
	end
	local profile = PlayerDataService.getProfile(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not profile or not root then
		return false
	end
	if (root.Position - coin.Position).Magnitude > EconomyConfig.Pickups.radius then
		return false
	end
	local result = ProfileOps.pickup(profile, TimeUtil.now())
	if not result.ok then
		local last = limitWarned[player]
		if not last or os.clock() - last > 15 then
			limitWarned[player] = os.clock()
			Remotes.notify(player, result.message, "warn")
		end
		return false
	end
	active[spot] = nil
	coin:Destroy()
	PlayerDataService.markDirty(player)
	Remotes.notify(player, "💰 +" .. result.coins .. " Coins (moeda perdida)", "coins")
	task.delay(EconomyConfig.Pickups.respawn, function()
		EconomyService.spawnCoin()
	end)
	return true
end

function EconomyService.spawnCoin()
	local free = {}
	for i = 1, #MapService.pickupSpots do
		if not active[i] then
			table.insert(free, i)
		end
	end
	if #free == 0 then
		return
	end
	local spot = free[rng:NextInteger(1, #free)]
	local pos = MapService.pickupSpots[spot]
	local coin = Instance.new("Part")
	coin.Name = "LostCoin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.4, 2.2, 2.2)
	coin.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(90), 0)
	coin.Color = Color3.fromRGB(255, 205, 50)
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin:SetAttribute("Spot", spot)
	coin.Parent = MapService.pickupFolder
	active[spot] = coin
	coin.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player then
			EconomyService.collect(player, spot)
		end
	end)
	return coin
end

function EconomyService.activeCoins()
	return active
end

function EconomyService.start()
	PlayerDataService.onLoaded(updateLeaderstats)
	PlayerDataService.onChanged(updateLeaderstats)
	PlayerDataService.onLeaving(function(player)
		limitWarned[player] = nil
	end)
	for _ = 1, EconomyConfig.Pickups.spots do
		EconomyService.spawnCoin()
	end
end

return EconomyService
