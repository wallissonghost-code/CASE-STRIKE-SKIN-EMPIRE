-- InventoryService: favoritar, equipar e desequipar, e exibição cosmética das skins equipadas
-- no personagem (sem ferramentas, sem dano: apenas modelos soldados nas costas/quadril).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ProfileOps = require(Shared.Logic.ProfileOps)
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local SkinModelFactory = require(Shared.Visual.SkinModelFactory)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local Validate = require(script.Parent.Parent.Core.Validate)
local PlayerDataService = require(script.Parent.PlayerDataService)

local InventoryService = {}

-- posições de exibição em relação ao UpperTorso/Torso
local DISPLAY_SLOTS = {
	CFrame.new(0, 0.1, 0.75) * CFrame.Angles(0, math.rad(90), math.rad(40)), -- costas (diagonal)
	CFrame.new(0, 0.1, 0.85) * CFrame.Angles(0, math.rad(90), math.rad(-40)), -- costas (cruzada)
	CFrame.new(-1.05, -0.9, 0) * CFrame.Angles(0, 0, math.rad(-80)), -- quadril esquerdo
	CFrame.new(1.05, -0.9, 0) * CFrame.Angles(0, math.rad(180), math.rad(-80)), -- quadril direito
}

local displayKeys = {} -- [player] = string com os itens exibidos

local function equippedList(profile)
	local list = {}
	for _, item in pairs(profile.inventory) do
		if item.equipped and item.location == "inventory" then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		return a.uid < b.uid
	end)
	return list
end

local function keyOf(list)
	local parts = {}
	for i, item in ipairs(list) do
		local ups = {}
		for k in pairs(item.upgrades or {}) do
			table.insert(ups, k)
		end
		table.sort(ups)
		parts[i] = item.uid .. ":" .. table.concat(ups, ",")
	end
	return table.concat(parts, "|")
end

local function refreshDisplay(player, force)
	local profile = PlayerDataService.getProfile(player)
	local character = player.Character
	if not profile or not character then
		return
	end
	local list = equippedList(profile)
	local key = keyOf(list)
	if not force and displayKeys[player] == key then
		return
	end
	displayKeys[player] = key

	local old = character:FindFirstChild("SkinDisplay")
	if old then
		old:Destroy()
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "SkinDisplay"
	for i, item in ipairs(list) do
		local slot = DISPLAY_SLOTS[i]
		if not slot then
			break
		end
		local def = SkinDefinitions.ById[item.defId]
		local model = SkinModelFactory.build(def, item.upgrades)
		local scale = def.category == "Knife" and 0.8 or 0.62
		model:ScaleTo(scale)
		SkinModelFactory.weldAssembly(model)
		model:PivotTo(torso.CFrame * slot)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = model.PrimaryPart
		weld.Parent = model.PrimaryPart
		model.Parent = folder
	end
	folder.Parent = character
end

function InventoryService.init() end

function InventoryService.start()
	Remotes.on("InventoryAction", "favorite", "Inventory", function(player, payload)
		if not Validate.id(payload.uid, 24) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.setFavorite(profile, ctx, payload.uid, payload.value == true)
		end)
	end)

	Remotes.on("InventoryAction", "equip", "Inventory", function(player, payload)
		if not Validate.id(payload.uid, 24) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.equip(profile, ctx, payload.uid)
		end)
	end)

	Remotes.on("InventoryAction", "unequip", "Inventory", function(player, payload)
		if not Validate.id(payload.uid, 24) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.unequip(profile, ctx, payload.uid)
		end)
	end)

	Remotes.on("InventoryAction", "showcase", "Inventory", function(player, payload)
		if not Validate.id(payload.uid, 24) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.setShowcase(profile, ctx, payload.uid, payload.value == true)
		end)
	end)

	Remotes.on("InventoryAction", "setReduceEffects", "Inventory", function(player, payload)
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.setReduceEffects(profile, ctx, payload.value == true)
		end)
	end)

	Remotes.on("InventoryAction", "setFastOpen", "Inventory", function(player, payload)
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.setFastOpen(profile, ctx, payload.value == true)
		end)
	end)

	PlayerDataService.onChanged(function(player)
		refreshDisplay(player, false)
	end)
	PlayerDataService.onLoaded(function(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.5)
			refreshDisplay(player, true)
		end)
		if player.Character then
			refreshDisplay(player, true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		displayKeys[player] = nil
	end)
end

return InventoryService
