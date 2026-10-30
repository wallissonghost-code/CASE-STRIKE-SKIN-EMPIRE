-- Constrói o parque (lobby compacto) por código ao iniciar o servidor:
-- praça central com spawn, 4 máquinas físicas ao norte, loja de melhorias a leste, painel de
-- ranking a oeste, galeria de vitrines ao sul, árvores, postes, caminhos e uma área "em breve".
-- Guarda as posições usadas pelos outros serviços (máquinas, vitrines, moedas, pontos de teleporte).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MachineDefinitions = require(Shared.MachineDefinitions)
local UpgradeConfig = require(Shared.UpgradeConfig)
local Format = require(Shared.Util.Format)

local MapService = {}

MapService.machines = {} -- [machineId] = { model, button, position, trayPoint }
MapService.booths = {} -- { { model, slots = { {pedestal, anchor} }, sign, position } }
MapService.pickupSpots = {}
MapService.points = {}
MapService.rankingBoard = nil -- Frame dentro do SurfaceGui do painel

local world

local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function part(parent, props)
	local p = Instance.new(props.class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = props.material or Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		if k ~= "class" and k ~= "material" then
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function label(parent, text, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 1, 0)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = C(255, 255, 255)
	l.TextStrokeTransparency = 0.4
	l.Text = text
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function surface(partInstance, face, pixelsPerStud)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	gui.LightInfluence = 0
	gui.Parent = partInstance
	return gui
end

local function prompt(parentPart, actionText, objectText, attrs)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = actionText
	pr.ObjectText = objectText
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr.KeyboardKeyCode = Enum.KeyCode.E
	for k, v in pairs(attrs or {}) do
		pr:SetAttribute(k, v)
	end
	pr.Parent = parentPart
	return pr
end

---------------------------------------------------------------------------
-- máquina
---------------------------------------------------------------------------
local function buildMachine(parent, def, origin)
	local model = Instance.new("Model")
	model.Name = "Machine_" .. def.id
	model:SetAttribute("MachineId", def.id)
	local function at(x, y, z)
		return origin * CFrame.new(x, y, z)
	end
	part(model, { Name = "Base", Size = Vector3.new(7.5, 1, 6.5), CFrame = at(0, 0.5, 0), Color = C(40, 40, 50) })
	local body = part(model, { Name = "Body", Size = Vector3.new(6.4, 9, 5), CFrame = at(0, 5.5, 0), Color = def.bodyColor })
	model.PrimaryPart = body
	part(model, { Name = "Top", Size = Vector3.new(7, 1.4, 5.6), CFrame = at(0, 10.7, 0), Color = def.accentColor })
	part(model, { Name = "TopDome", Size = Vector3.new(4.5, 4.5, 4.5), CFrame = at(0, 11.4, 0), Color = def.accentColor, Shape = Enum.PartType.Ball, material = Enum.Material.Glass, Transparency = 0.35 })
	-- visor transparente com cápsulas dentro
	part(model, { Name = "VisorBack", Size = Vector3.new(4.8, 4.4, 0.3), CFrame = at(0, 7, 1.2), Color = C(25, 25, 35) })
	part(model, { Name = "Visor", Size = Vector3.new(5, 4.6, 0.25), CFrame = at(0, 7, 2.6), Color = C(200, 235, 255), material = Enum.Material.Glass, Transparency = 0.55 })
	part(model, { Name = "VisorFrame", Size = Vector3.new(5.4, 0.35, 0.4), CFrame = at(0, 9.4, 2.55), Color = def.accentColor })
	part(model, { Name = "VisorFrame", Size = Vector3.new(5.4, 0.35, 0.4), CFrame = at(0, 4.6, 2.55), Color = def.accentColor })
	local capsules = folder(model, "Capsules")
	local capsuleColors = { C(255, 90, 90), C(90, 200, 255), C(255, 220, 70), C(140, 255, 120), C(220, 120, 255), C(255, 160, 60) }
	for i = 1, 6 do
		local col = (i - 1) % 3
		local row = math.floor((i - 1) / 3)
		part(capsules, {
			Name = "Capsule",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.1, 1.1, 1.1),
			CFrame = at(-1.4 + col * 1.4, 6.1 + row * 1.6, 1.95),
			Color = capsuleColors[i],
			CanCollide = false,
		})
	end
	local light = Instance.new("PointLight")
	light.Name = "VisorLight"
	light.Color = def.lightColor
	light.Range = 10
	light.Brightness = 1
	light.Parent = model:FindFirstChild("VisorBack")
	-- compartimento de entrega
	part(model, { Name = "Tray", Size = Vector3.new(3.4, 1.8, 1.6), CFrame = at(-0.6, 2.4, 2.6), Color = C(20, 20, 25) })
	part(model, { Name = "TrayLip", Size = Vector3.new(3.6, 0.3, 0.4), CFrame = at(-0.6, 1.4, 3.3), Color = def.accentColor })
	local trayPoint = part(model, { Name = "TrayPoint", Size = Vector3.new(0.5, 0.5, 0.5), CFrame = at(-0.6, 3.0, 4.2), Transparency = 1, CanCollide = false, CanQuery = false })
	-- botão de interação
	local button = part(model, {
		Name = "Button",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 1.3, 1.3),
		CFrame = at(2.1, 3.0, 2.65) * CFrame.Angles(0, math.rad(90), 0),
		Color = C(255, 60, 60),
		material = Enum.Material.Neon,
	})
	part(model, { Name = "ButtonRing", Size = Vector3.new(1.7, 1.7, 0.3), CFrame = at(2.1, 3.0, 2.55), Color = C(240, 240, 240) })
	prompt(button, "Usar máquina", def.name, { MachineId = def.id })
	-- luzes
	local lights = folder(model, "Lights")
	for i = 0, 6 do
		part(lights, { Name = "Light", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = at(-3 + i, 10.2, 2.85), Color = def.lightColor, material = Enum.Material.Neon, CanCollide = false })
	end
	for i = 0, 4 do
		part(lights, { Name = "Light", Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45), CFrame = at(-3.25, 2 + i * 1.8, 2.55), Color = def.lightColor, material = Enum.Material.Neon, CanCollide = false })
		part(lights, { Name = "Light", Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45), CFrame = at(3.25, 2 + i * 1.8, 2.55), Color = def.lightColor, material = Enum.Material.Neon, CanCollide = false })
	end
	-- placa com nome, preço e nível
	local sign = part(model, { Name = "Sign", Size = Vector3.new(7, 2.2, 0.3), CFrame = at(0, 14.6, 0.5), Color = C(30, 30, 40) })
	local gui = surface(sign, Enum.NormalId.Front, 30)
	label(gui, def.name, { Size = UDim2.new(1, 0, 0.6, 0) })
	label(gui, "💰 " .. Format.int(def.price) .. " Coins  •  Nível " .. def.level .. "+", {
		Size = UDim2.new(1, 0, 0.4, 0),
		Position = UDim2.new(0, 0, 0.6, 0),
		TextColor3 = C(255, 230, 120),
	})
	model.Parent = parent
	return model, button, trayPoint
end

---------------------------------------------------------------------------
-- decoração
---------------------------------------------------------------------------
local function tree(parent, x, z, scale)
	scale = scale or 1
	part(parent, { Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5 * scale, 1.4 * scale, 1.4 * scale), CFrame = CFrame.new(x, 2.5 * scale, z) * CFrame.Angles(0, 0, math.rad(90)), Color = C(120, 80, 50), material = Enum.Material.Wood })
	part(parent, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6) * scale, CFrame = CFrame.new(x, 6.5 * scale, z), Color = C(70, 175, 80), material = Enum.Material.Grass, CanCollide = false })
	part(parent, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4) * scale, CFrame = CFrame.new(x + 1.2 * scale, 8.6 * scale, z - 0.6 * scale), Color = C(95, 200, 95), material = Enum.Material.Grass, CanCollide = false })
end

local function lamp(parent, x, z, color)
	part(parent, { Name = "Pole", Size = Vector3.new(0.5, 8, 0.5), CFrame = CFrame.new(x, 4, z), Color = C(50, 50, 60), material = Enum.Material.Metal })
	local bulb = part(parent, { Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(x, 8.4, z), Color = color or C(255, 240, 180), material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 0.8
	light.Color = color or C(255, 240, 180)
	light.Parent = bulb
end

local function path(parent, from, to, width)
	local mid = (from + to) / 2
	local delta = to - from
	local length = delta.Magnitude
	local size
	if math.abs(delta.X) > math.abs(delta.Z) then
		size = Vector3.new(length, 0.2, width)
	else
		size = Vector3.new(width, 0.2, length)
	end
	part(parent, { Name = "Path", Size = size, CFrame = CFrame.new(mid.X, 0.1, mid.Z), Color = C(235, 215, 175), material = Enum.Material.Sand, CanCollide = true })
end

---------------------------------------------------------------------------
-- áreas
---------------------------------------------------------------------------
local function buildShop(parent)
	local m = Instance.new("Model")
	m.Name = "UpgradeShop"
	local x, z = 58, 0
	part(m, { Name = "Floor", Size = Vector3.new(14, 0.4, 16), CFrame = CFrame.new(x, 0.2, z), Color = C(250, 240, 220) })
	part(m, { Name = "Back", Size = Vector3.new(1, 10, 16), CFrame = CFrame.new(x + 6.5, 5, z), Color = C(90, 60, 160) })
	local counter = part(m, { Name = "Counter", Size = Vector3.new(3, 3.4, 10), CFrame = CFrame.new(x + 1, 1.7, z), Color = C(255, 180, 60) })
	for i = 0, 7 do
		part(m, { Name = "Awning", Size = Vector3.new(8, 0.4, 2), CFrame = CFrame.new(x + 2.5, 10.2, z - 7 + i * 2) * CFrame.Angles(0, 0, math.rad(-12)), Color = (i % 2 == 0) and C(255, 90, 120) or C(255, 255, 255) })
	end
	local sign = part(m, { Name = "Sign", Size = Vector3.new(0.4, 2.6, 12), CFrame = CFrame.new(x - 1.8, 12.2, z), Color = C(40, 30, 70) })
	local gui = surface(sign, Enum.NormalId.Left, 30)
	label(gui, "⚙️ MELHORIAS")
	prompt(counter, "Abrir loja", "Melhorias", { Panel = "Upgrades" })
	m.Parent = parent
	MapService.points.shop = Vector3.new(x - 6, 3, z)
end

local function buildRanking(parent)
	local m = Instance.new("Model")
	m.Name = "RankingBoard"
	local x, z = -58, 0
	part(m, { Name = "Floor", Size = Vector3.new(10, 0.4, 22), CFrame = CFrame.new(x, 0.2, z), Color = C(220, 230, 245) })
	part(m, { Name = "Leg", Size = Vector3.new(1, 6, 1), CFrame = CFrame.new(x - 2, 3, z - 9), Color = C(50, 50, 60) })
	part(m, { Name = "Leg", Size = Vector3.new(1, 6, 1), CFrame = CFrame.new(x - 2, 3, z + 9), Color = C(50, 50, 60) })
	local board = part(m, { Name = "Board", Size = Vector3.new(0.6, 11, 22), CFrame = CFrame.new(x - 2, 11, z), Color = C(25, 25, 40) })
	local gui = surface(board, Enum.NormalId.Right, 25)
	local frame = Instance.new("Frame")
	frame.Name = "Content"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	label(frame, "🏆 RANKING", { Name = "Title", Size = UDim2.new(1, 0, 0.14, 0) })
	MapService.rankingBoard = frame
	prompt(board, "Ver ranking", "Ranking", { Panel = "Ranking" })
	m.Parent = parent
	MapService.points.ranking = Vector3.new(x + 6, 3, z)
end

local function buildGallery(parent)
	local gallery = Instance.new("Model")
	gallery.Name = "Gallery"
	part(gallery, { Name = "Floor", Size = Vector3.new(96, 0.4, 62), CFrame = CFrame.new(0, 0.2, 76), Color = C(240, 235, 250), material = Enum.Material.Marble })
	local arch = part(gallery, { Name = "Arch", Size = Vector3.new(30, 3, 1), CFrame = CFrame.new(0, 12, 45), Color = C(120, 80, 200) })
	part(gallery, { Name = "ArchLeg", Size = Vector3.new(1.5, 12, 1.5), CFrame = CFrame.new(-15, 6, 45), Color = C(120, 80, 200) })
	part(gallery, { Name = "ArchLeg", Size = Vector3.new(1.5, 12, 1.5), CFrame = CFrame.new(15, 6, 45), Color = C(120, 80, 200) })
	label(surface(arch, Enum.NormalId.Back, 25), "🏛️ GALERIA DE VITRINES")
	local index = 0
	for row = 0, 1 do
		for col = 0, 3 do
			index = index + 1
			local cx, cz = -36 + col * 24, 62 + row * 28
			local booth = Instance.new("Model")
			booth.Name = "Booth" .. index
			part(booth, { Name = "Tile", Size = Vector3.new(21, 0.3, 22), CFrame = CFrame.new(cx, 0.55, cz), Color = (index % 2 == 0) and C(220, 210, 245) or C(210, 230, 250) })
			part(booth, { Name = "BackWall", Size = Vector3.new(21, 7, 0.8), CFrame = CFrame.new(cx, 3.9, cz + 10.6), Color = C(110, 90, 170) })
			local sign = part(booth, { Name = "Sign", Size = Vector3.new(14, 2.4, 0.4), CFrame = CFrame.new(cx, 8.6, cz + 10.6), Color = C(40, 30, 60) })
			local signLabel = label(surface(sign, Enum.NormalId.Front, 25), "Vitrine livre", { Name = "Owner" })
			local slots = {}
			for i = 1, UpgradeConfig.MaxShowcaseSlots do
				local sx = cx - 6 + ((i - 1) % 3) * 6
				local sz = cz - 3 + math.floor((i - 1) / 3) * 8
				local pedestal = part(booth, { Name = "Pedestal" .. i, Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(sx, 2.2, sz), Color = C(250, 250, 255), material = Enum.Material.Marble })
				local glass = part(booth, { Name = "Glass" .. i, Size = Vector3.new(3.2, 3.6, 3.2), CFrame = CFrame.new(sx, 5.5, sz), Color = C(210, 240, 255), material = Enum.Material.Glass, Transparency = 0.8, CanCollide = false })
				table.insert(slots, { pedestal = pedestal, glass = glass, anchor = CFrame.new(sx, 5.4, sz) })
			end
			booth.Parent = gallery
			table.insert(MapService.booths, { model = booth, slots = slots, sign = signLabel, position = Vector3.new(cx, 3, cz - 9) })
		end
	end
	gallery.Parent = parent
	MapService.points.gallery = Vector3.new(0, 3, 50)
end

local function buildFutureArea(parent)
	local m = Instance.new("Model")
	m.Name = "FutureArea"
	local x, z = 70, -70
	part(m, { Name = "Ground", Size = Vector3.new(36, 0.3, 36), CFrame = CFrame.new(x, 0.15, z), Color = C(200, 170, 120), material = Enum.Material.Ground })
	for i = 0, 8 do
		local stripe = (i % 2 == 0) and C(255, 200, 0) or C(30, 30, 30)
		part(m, { Name = "Barrier", Size = Vector3.new(4, 1, 0.5), CFrame = CFrame.new(x - 16 + i * 4, 2.5, z + 18), Color = stripe })
		part(m, { Name = "Barrier", Size = Vector3.new(0.5, 1, 4), CFrame = CFrame.new(x - 18, 2.5, z - 16 + i * 4), Color = stripe })
	end
	part(m, { Name = "Wall", Size = Vector3.new(36, 6, 0.5), CFrame = CFrame.new(x, 3, z + 18.5), Transparency = 1 })
	part(m, { Name = "Wall", Size = Vector3.new(0.5, 6, 36), CFrame = CFrame.new(x - 18.5, 3, z), Transparency = 1 })
	local sign = part(m, { Name = "Sign", Size = Vector3.new(12, 3, 0.4), CFrame = CFrame.new(x - 2, 5, z + 19.2) * CFrame.Angles(0, math.rad(180), 0), Color = C(255, 200, 0) })
	label(surface(sign, Enum.NormalId.Back, 25), "🚧 NOVA ÁREA EM BREVE", { TextColor3 = C(30, 30, 30), TextStrokeTransparency = 1 })
	m.Parent = parent
end

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = C(110, 110, 130)
	Lighting.OutdoorAmbient = C(150, 150, 170)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.5
end

function MapService.build()
	setupLighting()
	world = Instance.new("Folder")
	world.Name = "MysteryPark"
	world.Parent = workspace

	local terrain = folder(world, "Ground")
	part(terrain, { Name = "Grass", Size = Vector3.new(220, 2, 220), CFrame = CFrame.new(0, -1, 0), Color = C(110, 190, 90), material = Enum.Material.Grass })
	part(terrain, { Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 56, 56), CFrame = CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = C(245, 225, 190), material = Enum.Material.Pebble })
	part(terrain, { Name = "PlazaRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 20, 20), CFrame = CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = C(255, 140, 170), material = Enum.Material.SmoothPlastic })
	local spawn = part(world, { class = "SpawnLocation", Name = "Spawn", Size = Vector3.new(8, 0.6, 8), CFrame = CFrame.new(0, 0.5, 8), Color = C(255, 210, 90), material = Enum.Material.Neon })
	spawn.Neutral = true
	spawn.Duration = 0
	MapService.points.plaza = Vector3.new(0, 3, 8)

	-- fonte decorativa no centro
	part(world, { Name = "Fountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 9, 9), CFrame = CFrame.new(0, 0.8, -6) * CFrame.Angles(0, 0, math.rad(90)), Color = C(200, 200, 215), material = Enum.Material.Marble })
	part(world, { Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 7.8, 7.8), CFrame = CFrame.new(0, 1.55, -6) * CFrame.Angles(0, 0, math.rad(90)), Color = C(90, 180, 255), material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
	part(world, { Name = "FountainOrb", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), CFrame = CFrame.new(0, 3.4, -6), Color = C(255, 120, 200), material = Enum.Material.Neon })

	local paths = folder(world, "Paths")
	path(paths, Vector3.new(0, 0, -26), Vector3.new(0, 0, -44), 10)
	path(paths, Vector3.new(0, 0, 26), Vector3.new(0, 0, 46), 10)
	path(paths, Vector3.new(26, 0, 0), Vector3.new(51, 0, 0), 8)
	path(paths, Vector3.new(-26, 0, 0), Vector3.new(-53, 0, 0), 8)

	-- máquinas lado a lado ao norte, de frente para a praça
	local machinesFolder = folder(world, "Machines")
	part(machinesFolder, { Name = "Platform", Size = Vector3.new(96, 0.6, 22), CFrame = CFrame.new(0, 0.3, -54), Color = C(60, 50, 90) })
	local arch = part(machinesFolder, { Name = "Banner", Size = Vector3.new(40, 4, 0.6), CFrame = CFrame.new(0, 21, -60), Color = C(255, 80, 160) })
	label(surface(arch, Enum.NormalId.Front, 20), "🎰 MYSTERY MACHINE")
	for i, def in ipairs(MachineDefinitions.List) do
		local x = -33 + (i - 1) * 22
		local origin = CFrame.new(x, 0.6, -56)
		local model, button, trayPoint = buildMachine(machinesFolder, def, origin)
		MapService.machines[def.id] = {
			model = model,
			button = button,
			trayPoint = trayPoint,
			position = button.Position,
			standPoint = Vector3.new(x, 3, -46),
		}
	end

	buildShop(world)
	buildRanking(world)
	buildGallery(world)
	buildFutureArea(world)

	local deco = folder(world, "Decoration")
	local trees = {
		{ -80, -80 }, { -60, -88 }, { -88, -50 }, { 88, -40 }, { 92, 10 }, { 80, 40 }, { -86, 20 }, { -90, 60 },
		{ -70, 92 }, { 70, 95 }, { 92, 75 }, { -40, -28 }, { 40, -30 }, { -40, 30 }, { 40, 28 }, { 0, -92 },
	}
	for i, t in ipairs(trees) do
		tree(deco, t[1], t[2], 0.9 + (i % 3) * 0.15)
	end
	for _, l in ipairs({ { -8, -34 }, { 8, -34 }, { -8, 36 }, { 8, 36 }, { 38, -6 }, { 38, 6 }, { -38, -6 }, { -38, 6 } }) do
		lamp(deco, l[1], l[2])
	end
	for _, f in ipairs({ { -18, -18 }, { 18, -18 }, { -18, 18 }, { 18, 18 } }) do
		part(deco, { Name = "Flowerbed", Size = Vector3.new(6, 0.8, 6), CFrame = CFrame.new(f[1], 0.4, f[2]), Color = C(120, 80, 50), material = Enum.Material.Ground })
		part(deco, { Name = "Flowers", Shape = Enum.PartType.Ball, Size = Vector3.new(4.5, 2, 4.5), CFrame = CFrame.new(f[1], 1.2, f[2]), Color = C(255, 120, 170), material = Enum.Material.Grass, CanCollide = false })
	end

	-- pontos onde aparecem as moedas perdidas
	for i = 0, 11 do
		local a = (i / 12) * math.pi * 2
		local r = (i % 2 == 0) and 22 or 34
		table.insert(MapService.pickupSpots, Vector3.new(math.cos(a) * r, 2, math.sin(a) * r))
	end
	MapService.pickupFolder = folder(world, "CoinPickups")
	MapService.showcaseFolder = folder(world, "ShowcaseItems")
	return world
end

function MapService.world()
	return world
end

function MapService.machinePosition(machineId)
	local m = MapService.machines[machineId]
	return m and m.position
end

return MapService
