-- Galeria de vitrines: cada jogador recebe um estande ao entrar e os objetos que escolheu expor
-- aparecem em 3D, com placa de nome, raridade e dono. Qualquer jogador pode visitar.
-- Os modelos são só exibição: o objeto continua UMA cópia do inventário (reservada para venda).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDefinitions = require(Shared.ItemDefinitions)
local RarityConfig = require(Shared.RarityConfig)
local UpgradeConfig = require(Shared.UpgradeConfig)
local ProfileOps = require(Shared.Logic.ProfileOps)
local ItemModels = require(Shared.Visual.ItemModels)
local Remotes = require(script.Parent.Parent.Core.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local MapService = require(script.Parent.MapService)

local ShowcaseService = {}

local owners = {} -- [boothIndex] = player
local boothOf = {} -- [player] = boothIndex
local rendered = {} -- [boothIndex] = assinatura do que está exibido

local function signature(profile)
	return table.concat(profile.showcase, ",") .. "|" .. ProfileOps.showcaseSlots(profile)
end

local function clearSlot(slot)
	if slot.model then
		slot.model:Destroy()
		slot.model = nil
	end
	if slot.plate then
		slot.plate:Destroy()
		slot.plate = nil
	end
end

local function plate(slot, text, color, sub)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Plate"
	gui.Size = UDim2.new(0, 160, 0, 46)
	gui.MaxDistance = 45
	local function line(t, y, h, c)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, h, 0)
		l.Position = UDim2.new(0, 0, y, 0)
		l.Font = Enum.Font.GothamBold
		l.TextScaled = true
		l.Text = t
		l.TextColor3 = c
		l.TextStrokeTransparency = 0.3
		l.Parent = gui
	end
	line(text, 0, 0.45, Color3.fromRGB(255, 255, 255))
	line(sub, 0.45, 0.3, color)
	gui.Parent = slot.pedestal
	gui.StudsOffsetWorldSpace = Vector3.new(0, 0.2, 0)
	slot.plate = gui
end

function ShowcaseService.render(index)
	local booth = MapService.booths[index]
	local player = owners[index]
	local profile = player and PlayerDataService.getProfile(player)
	local sig = profile and signature(profile) or "empty"
	if rendered[index] == sig then
		return
	end
	rendered[index] = sig
	booth.sign.Text = player and ("🏛️ Vitrine de " .. player.DisplayName) or "Vitrine livre"
	local slots = profile and ProfileOps.showcaseSlots(profile) or 0
	for i, slot in ipairs(booth.slots) do
		clearSlot(slot)
		local itemId = profile and profile.showcase[i] or ""
		local item = ItemDefinitions.get(itemId)
		slot.glass.Transparency = (profile and i <= slots) and 0.8 or 1
		if item and i <= slots then
			local model = ItemModels.build(itemId)
			model:PivotTo(slot.anchor)
			model.Parent = MapService.showcaseFolder
			slot.model = model
			local rarity = RarityConfig.get(item.rarity)
			plate(slot, item.name, rarity.color, rarity.name .. " • de " .. player.DisplayName)
		elseif profile and i > slots then
			plate(slot, "🔒", Color3.fromRGB(200, 200, 200), "Melhoria Vitrines")
		end
	end
end

local function assign(player)
	for i = 1, #MapService.booths do
		if not owners[i] then
			owners[i] = player
			boothOf[player] = i
			ShowcaseService.render(i)
			return i
		end
	end
	Remotes.notify(player, "Todas as vitrines da galeria estão ocupadas neste servidor.", "warn")
	return nil
end

function ShowcaseService.boothOf(player)
	return boothOf[player]
end

function ShowcaseService.boothPosition(player)
	local i = boothOf[player]
	return i and MapService.booths[i].position
end

function ShowcaseService.start()
	PlayerDataService.onLoaded(assign)
	PlayerDataService.onChanged(function(player)
		local i = boothOf[player]
		if i then
			ShowcaseService.render(i)
		end
	end)
	PlayerDataService.onLeaving(function(player)
		local i = boothOf[player]
		if i then
			owners[i] = nil
			boothOf[player] = nil
			ShowcaseService.render(i)
		end
	end)
	assert(#MapService.booths[1].slots == UpgradeConfig.MaxShowcaseSlots)
end

return ShowcaseService
