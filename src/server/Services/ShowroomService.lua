-- ShowroomService: cada jogador ganha uma vitrine no Showroom do lobby, visível e visitável por
-- todos. Mostra até EconomyConfig.ShowcaseSlots skins escolhidas no inventário ("Expor"),
-- em pedestais com placa (nome, coleção, raridade) e luz na cor da raridade.
-- Puramente cosmético: expor uma skin não dá nenhuma vantagem econômica.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local CaseDefinitions = require(Shared.Config.CaseDefinitions)
local RarityConfig = require(Shared.Config.RarityConfig)
local SkinModelFactory = require(Shared.Visual.SkinModelFactory)

local PlayerDataService = require(script.Parent.PlayerDataService)

local ShowroomService = {}

local booths = {} -- lista de partes-base (ordem fixa)
local owner = {} -- [boothIndex] = player
local boothOf = {} -- [player] = boothIndex
local keys = {} -- [player] = assinatura do que está exposto

-- posições dos pedestais em relação à base (3 × 2, voltados para o corredor)
local SPOTS = {
	CFrame.new(-6, 0, -2), CFrame.new(0, 0, -3), CFrame.new(6, 0, -2),
	CFrame.new(-6, 0, 3), CFrame.new(0, 0, 4), CFrame.new(6, 0, 3),
}

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function clearBooth(index)
	local base = booths[index]
	if not base then
		return
	end
	local old = base:FindFirstChild("Display")
	if old then
		old:Destroy()
	end
end

-- decoração temática: usa a coleção mais alta cuja vitrine o jogador desbloqueou
local function themeColor(profile)
	local best = nil
	for _, c in ipairs(CaseDefinitions.List) do
		if profile.cosmetics and profile.cosmetics["showcase_" .. c.id] then
			best = c
		end
	end
	return best and rgb(best.trim) or Color3.fromRGB(230, 225, 215), best
end

local function label(parent, text, size, color, offset)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(170, 40)
	bb.StudsOffset = offset or Vector3.new(0, 0, 0)
	bb.MaxDistance = 45
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextWrapped = true
	t.Font = Enum.Font.GothamBold
	t.TextSize = size
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.35
	t.Parent = bb
	bb.Parent = parent
	return bb
end

local function render(player)
	local index = boothOf[player]
	local profile = PlayerDataService.getProfile(player)
	if not index or not profile then
		return
	end
	local shown = {}
	for _, item in pairs(profile.inventory) do
		if item.showcase and item.location == "inventory" then
			table.insert(shown, item)
		end
	end
	table.sort(shown, function(a, b)
		return a.uid < b.uid
	end)
	local parts = { player.DisplayName }
	for _, item in ipairs(shown) do
		local ups = {}
		for k in pairs(item.upgrades or {}) do
			table.insert(ups, k)
		end
		table.sort(ups)
		table.insert(parts, item.defId .. ":" .. table.concat(ups, ","))
	end
	local _, theme = themeColor(profile)
	table.insert(parts, theme and theme.id or "")
	local key = table.concat(parts, "|")
	if keys[player] == key then
		return
	end
	keys[player] = key

	clearBooth(index)
	local base = booths[index]
	local folder = Instance.new("Folder")
	folder.Name = "Display"
	local trim = themeColor(profile)

	local signPart = Instance.new("Part")
	signPart.Name = "Sign"
	signPart.Anchored = true
	signPart.CanCollide = false
	signPart.Size = Vector3.new(10, 2, 0.4)
	signPart.Color = trim
	signPart.Material = Enum.Material.Neon
	signPart.CFrame = base.CFrame * CFrame.new(0, 6, -7)
	signPart.Parent = folder
	label(signPart, "Vitrine de " .. player.DisplayName, 18, Color3.new(1, 1, 1), Vector3.new(0, 1.6, 0))

	for i, item in ipairs(shown) do
		local spot = SPOTS[i]
		if not spot then
			break
		end
		local def = SkinDefinitions.ById[item.defId]
		local rarity = RarityConfig.Rarities[def.rarity]
		local pedestal = Instance.new("Part")
		pedestal.Name = "Pedestal"
		pedestal.Anchored = true
		pedestal.Size = Vector3.new(3.2, 2.4, 3.2)
		pedestal.Material = Enum.Material.Marble
		pedestal.Color = Color3.fromRGB(240, 238, 232)
		pedestal.CFrame = base.CFrame * spot * CFrame.new(0, 1.2, 0)
		pedestal.Parent = folder
		local ring = Instance.new("Part")
		ring.Name = "RarityRing"
		ring.Anchored = true
		ring.CanCollide = false
		ring.Size = Vector3.new(3.4, 0.25, 3.4)
		ring.Material = Enum.Material.Neon
		ring.Color = rgb(rarity.color)
		ring.CFrame = pedestal.CFrame * CFrame.new(0, 1.2, 0)
		ring.Parent = folder
		local light = Instance.new("PointLight")
		light.Color = rgb(rarity.color)
		light.Brightness = 1.4
		light.Range = 9
		light.Parent = ring

		local model = SkinModelFactory.build(def, item.upgrades)
		model:ScaleTo(def.category == "Knife" and 1.0 or 0.75)
		model:PivotTo(pedestal.CFrame * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, math.rad(90), math.rad(-12)))
		model:SetAttribute("Spin", true) -- o cliente gira as skins expostas
		model.Parent = folder
		local caseDef = CaseDefinitions.ById[def.caseId]
		label(pedestal, def.name .. "\n" .. rarity.displayName .. " • " .. caseDef.collectionName, 12, rgb(rarity.color), Vector3.new(0, -0.4, 0))
	end
	if #shown == 0 then
		label(signPart, "Escolha skins em Itens → Expor no showroom", 12, Color3.fromRGB(220, 220, 230), Vector3.new(0, -1.6, 0))
	end
	folder.Parent = base
end

local function assign(player)
	if boothOf[player] then
		return
	end
	for i = 1, #booths do
		if not owner[i] then
			owner[i] = player
			boothOf[player] = i
			player:SetAttribute("ShowroomBooth", i)
			render(player)
			return
		end
	end
	-- sem vitrines livres (servidor lotado): o jogador continua podendo visitar as outras
end

function ShowroomService.init() end

function ShowroomService.start()
	local lobby = workspace:WaitForChild("Lobby", 30)
	local room = lobby and lobby:FindFirstChild("Showroom")
	local boothFolder = room and room:FindFirstChild("Booths")
	if boothFolder then
		local list = boothFolder:GetChildren()
		table.sort(list, function(a, b)
			return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
		end)
		for _, b in ipairs(list) do
			table.insert(booths, b)
		end
	end

	PlayerDataService.onLoaded(function(player)
		assign(player)
	end)
	PlayerDataService.onChanged(function(player)
		render(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local i = boothOf[player]
		if i then
			clearBooth(i)
			owner[i] = nil
		end
		boothOf[player] = nil
		keys[player] = nil
	end)
end

return ShowroomService
