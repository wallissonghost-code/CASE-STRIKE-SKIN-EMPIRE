-- MapService: constrói o mapa inteiro por código (sem modelos ou texturas externas):
-- chão, praça, esteira da fábrica, quiosques de ovos, loja de poções, placa de eventos,
-- 6 bases com pedestais, terminais (coletar / travar base) e as barreiras de laser.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local MapConfig = require(Shared.Config.MapConfig)

local MapService = {}

MapService.world = nil
MapService.bases = {} -- [index] = { folder, pads = {}, laser = {}, sign, collectPrompt, shieldPrompt }
MapService.eventLabel = nil

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- placa com texto (BillboardGui sempre virado para a câmera)
function MapService.billboard(adornee, text, size, offsetY, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = size or UDim2.fromOffset(220, 60)
	gui.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 140
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.RichText = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	gui.Parent = adornee
	return label
end

local function prompt(parent, actionText, objectText, opts)
	opts = opts or {}
	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionText
	p.ObjectText = objectText or ""
	p.HoldDuration = opts.hold or 0
	p.MaxActivationDistance = opts.distance or 10
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	for k, v in pairs(opts.attributes or {}) do
		p:SetAttribute(k, v)
	end
	p.Parent = parent
	return p
end
MapService.prompt = prompt

local function buildPlaza(world)
	part(world, { Name = "Ground", Size = Vector3.new(MapConfig.GroundSize, 2, MapConfig.GroundSize), Position = Vector3.new(0, -1, 0), Color = Color3.fromRGB(96, 178, 74), Material = Enum.Material.Grass })
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, 30)
	spawn.Color = Color3.fromRGB(120, 255, 90)
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Parent = world
	part(world, { Name = "Plaza", Size = Vector3.new(170, 0.4, 90), Position = Vector3.new(0, 0.2, 0), Color = Color3.fromRGB(200, 196, 186), Material = Enum.Material.Concrete })
	-- caminhos até as bases
	for _, b in ipairs(MapConfig.Bases) do
		local len = math.abs(b.z) - MapConfig.BaseSize / 2 - 45
		part(world, { Name = "Path", Size = Vector3.new(14, 0.3, len), Position = Vector3.new(b.x, 0.15, b.facing * -(45 + len / 2)), Color = Color3.fromRGB(214, 200, 160), Material = Enum.Material.Sand })
	end
	part(world, { Name = "Road", Size = Vector3.new(260, 0.3, 14), Position = Vector3.new(0, 0.15, -50), Color = Color3.fromRGB(214, 200, 160), Material = Enum.Material.Sand })
	part(world, { Name = "Road", Size = Vector3.new(260, 0.3, 14), Position = Vector3.new(0, 0.15, 50), Color = Color3.fromRGB(214, 200, 160), Material = Enum.Material.Sand })
	-- cerca
	local f = MapConfig.Fence
	for _, w in ipairs({ { 0, -f, f * 2, 1 }, { 0, f, f * 2, 1 }, { -f, 0, 1, f * 2 }, { f, 0, 1, f * 2 } }) do
		part(world, { Name = "Fence", Size = Vector3.new(w[3], 6, w[4]), Position = Vector3.new(w[1], 3, w[2]), Color = Color3.fromRGB(240, 230, 210), Material = Enum.Material.WoodPlanks })
	end
	-- árvores de enfeite nos cantos
	for _, t in ipairs({ { -185, -185 }, { 185, -185 }, { -185, 185 }, { 185, 185 }, { -185, 0 }, { 185, 0 }, { -60, -185 }, { 60, 185 } }) do
		part(world, { Name = "Trunk", Size = Vector3.new(2, 8, 2), Position = Vector3.new(t[1], 4, t[2]), Color = Color3.fromRGB(110, 75, 40), Material = Enum.Material.Wood })
		part(world, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(11, 11, 11), Position = Vector3.new(t[1], 11, t[2]), Color = Color3.fromRGB(60, 150, 70), Material = Enum.Material.Grass })
	end
end

local function buildConveyor(world)
	local c = MapConfig.Conveyor
	local len = c.endX - c.startX
	local belt = part(world, { Name = "ConveyorBelt", Size = Vector3.new(len + 8, 1.2, c.width), Position = Vector3.new((c.startX + c.endX) / 2, 0.8, c.z), Color = Color3.fromRGB(45, 48, 60), Material = Enum.Material.DiamondPlate })
	for x = c.startX, c.endX, 8 do
		part(world, { Name = "Arrow", Size = Vector3.new(3, 0.1, 1), Position = Vector3.new(x, 1.45, c.z), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Neon, CanCollide = false })
	end
	for _, side in ipairs({ -1, 1 }) do
		part(world, { Name = "Rail", Size = Vector3.new(len + 8, 1.6, 0.8), Position = Vector3.new((c.startX + c.endX) / 2, 1.6, c.z + side * (c.width / 2 + 0.4)), Color = Color3.fromRGB(255, 170, 40), Material = Enum.Material.Metal })
	end
	-- máquina da fábrica no início da esteira
	local machine = part(world, { Name = "FactoryMachine", Size = Vector3.new(16, 18, 18), Position = Vector3.new(c.startX - 12, 9, c.z), Color = Color3.fromRGB(70, 80, 110), Material = Enum.Material.Metal })
	part(world, { Name = "FactoryPipe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 4, 4), Position = Vector3.new(c.startX - 12, 22, c.z - 4), Orientation = Vector3.new(0, 0, 90), Color = Color3.fromRGB(120, 255, 90), Material = Enum.Material.Neon })
	part(world, { Name = "FactoryHatch", Size = Vector3.new(1, 8, 9), Position = Vector3.new(c.startX - 3.6, 5, c.z), Color = Color3.fromRGB(120, 255, 90), Material = Enum.Material.Neon })
	MapService.billboard(machine, "🧪 MUTANT FACTORY", UDim2.fromOffset(420, 80), 14, Color3.fromRGB(150, 255, 110))
	-- recolhedor no final
	part(world, { Name = "Recycler", Size = Vector3.new(10, 12, 14), Position = Vector3.new(c.endX + 9, 6, c.z), Color = Color3.fromRGB(90, 60, 60), Material = Enum.Material.Metal })
	return belt
end

local function buildKiosks(world)
	for _, id in ipairs(GameConfig.EggOrder) do
		local egg = GameConfig.Eggs[id]
		local k = MapConfig.EggKiosks[id]
		local stand = part(world, { Name = "EggKiosk_" .. id, Size = Vector3.new(10, 3, 10), Position = Vector3.new(k.x, 1.5, k.z), Color = Color3.fromRGB(60, 64, 84), Material = Enum.Material.Metal })
		local eggPart = part(world, { Name = "Egg_" .. id, Shape = Enum.PartType.Ball, Size = Vector3.new(5, 6.5, 5), Position = Vector3.new(k.x, 6.4, k.z), Color = rgb(egg.color), Material = Enum.Material.SmoothPlastic })
		MapService.billboard(eggPart, egg.name .. "\n<font color='#FFD84A'>$ " .. tostring(egg.price) .. "</font>", UDim2.fromOffset(220, 70), 6)
		prompt(stand, "Abrir", egg.name, { distance = 12, attributes = { Panel = "Eggs", EggId = id } })
	end
	local ps = MapConfig.PotionShop
	local shop = part(world, { Name = "PotionShop", Size = Vector3.new(12, 6, 8), Position = Vector3.new(ps.x, 3, ps.z), Color = Color3.fromRGB(120, 60, 170), Material = Enum.Material.WoodPlanks })
	part(world, { Name = "PotionBottle", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), Position = Vector3.new(ps.x, 7.6, ps.z), Color = Color3.fromRGB(120, 255, 120), Material = Enum.Material.Neon })
	MapService.billboard(shop, "🧪 POÇÕES", UDim2.fromOffset(200, 50), 7)
	prompt(shop, "Ver poções", "Loja de Poções", { distance = 12, attributes = { Panel = "Potions" } })

	local eb = MapConfig.EventBoard
	local board = part(world, { Name = "EventBoard", Size = Vector3.new(16, 9, 1), Position = Vector3.new(eb.x, 7, eb.z), Color = Color3.fromRGB(30, 34, 50) })
	part(world, { Name = "EventBoardPost", Size = Vector3.new(1, 4, 1), Position = Vector3.new(eb.x, 1.5, eb.z), Color = Color3.fromRGB(60, 60, 70) })
	MapService.eventLabel = MapService.billboard(board, "Eventos", UDim2.fromOffset(360, 110), 0)
	MapService.eventLabel.Parent.AlwaysOnTop = false
end

local function buildBase(world, index)
	local b = MapConfig.Bases[index]
	local color = rgb(MapConfig.BaseColors[index])
	local folder = Instance.new("Folder")
	folder.Name = "Base" .. index
	folder.Parent = world
	local size = MapConfig.BaseSize
	part(folder, { Name = "Floor", Size = Vector3.new(size, 1, size), Position = Vector3.new(b.x, 0.5, b.z), Color = Color3.fromRGB(70, 74, 92), Material = Enum.Material.Slate })
	part(folder, { Name = "Rim", Size = Vector3.new(size + 2, 0.6, size + 2), Position = Vector3.new(b.x, 0.3, b.z), Color = color, Material = Enum.Material.Neon })
	-- paredes (fundo e laterais) e entrada voltada para a praça
	local wallColor = color:Lerp(Color3.fromRGB(40, 40, 50), 0.55)
	part(folder, { Name = "WallBack", Size = Vector3.new(size, 10, 2), Position = Vector3.new(b.x, 5.5, b.z - b.facing * size / 2), Color = wallColor })
	part(folder, { Name = "WallLeft", Size = Vector3.new(2, 10, size), Position = Vector3.new(b.x - size / 2, 5.5, b.z), Color = wallColor })
	part(folder, { Name = "WallRight", Size = Vector3.new(2, 10, size), Position = Vector3.new(b.x + size / 2, 5.5, b.z), Color = wallColor })
	local frontZ = b.z + b.facing * size / 2
	part(folder, { Name = "WallFrontL", Size = Vector3.new(size / 2 - 9, 10, 2), Position = Vector3.new(b.x - size / 4 - 4.5, 5.5, frontZ), Color = wallColor })
	part(folder, { Name = "WallFrontR", Size = Vector3.new(size / 2 - 9, 10, 2), Position = Vector3.new(b.x + size / 4 + 4.5, 5.5, frontZ), Color = wallColor })
	-- laser da entrada (aparece com o escudo ligado)
	local laser = {}
	for i = 0, 3 do
		table.insert(laser, part(folder, { Name = "Laser", Size = Vector3.new(18, 0.4, 0.4), Position = Vector3.new(b.x, 1.5 + i * 2.2, frontZ), Color = Color3.fromRGB(255, 50, 60), Material = Enum.Material.Neon, CanCollide = false, Transparency = 1 }))
	end
	-- placa do dono
	local signPost = part(folder, { Name = "OwnerSign", Size = Vector3.new(20, 5, 1), Position = Vector3.new(b.x, 14, frontZ), Color = color })
	local sign = MapService.billboard(signPost, "Base livre", UDim2.fromOffset(320, 70), 2)
	-- pedestais
	local pads = {}
	for i = 1, GameConfig.Base.MaxSlotsShown do
		local x, z = MapConfig.padPosition(index, i)
		pads[i] = part(folder, { Name = "Pad" .. i, Size = Vector3.new(8, 1, 8), Position = Vector3.new(x, 1.3, z), Color = Color3.fromRGB(45, 48, 62), Material = Enum.Material.Metal, Transparency = 0.6 })
	end
	-- terminais
	local cx, cz = MapConfig.toWorld(index, MapConfig.Terminal.collect.lx, MapConfig.Terminal.collect.lz)
	local collect = part(folder, { Name = "CollectTerminal", Size = Vector3.new(6, 4, 3), Position = Vector3.new(cx, 3, cz), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Neon })
	MapService.billboard(collect, "💰 COLETAR", UDim2.fromOffset(160, 40), 4)
	local sx, sz = MapConfig.toWorld(index, MapConfig.Terminal.shield.lx, MapConfig.Terminal.shield.lz)
	local shield = part(folder, { Name = "ShieldTerminal", Size = Vector3.new(6, 4, 3), Position = Vector3.new(sx, 3, sz), Color = Color3.fromRGB(80, 170, 255), Material = Enum.Material.Neon })
	local shieldLabel = MapService.billboard(shield, "🛡️ TRAVAR BASE", UDim2.fromOffset(200, 40), 4)
	local spx, spz = MapConfig.toWorld(index, MapConfig.Terminal.spawn.lx, MapConfig.Terminal.spawn.lz)
	MapService.bases[index] = {
		folder = folder,
		pads = pads,
		laser = laser,
		sign = sign,
		shieldLabel = shieldLabel,
		collectPrompt = prompt(collect, "Coletar tudo", "Sua base", { distance = 12, attributes = { OwnerOnly = true, BaseIndex = index, Action = "collect" } }),
		shieldPrompt = prompt(shield, "Travar base", "Escudo", { distance = 12, attributes = { OwnerOnly = true, BaseIndex = index, Action = "shield" } }),
		spawn = Vector3.new(spx, 4, spz),
		color = color,
	}
end

function MapService.init()
	local world = Instance.new("Folder")
	world.Name = "MutantWorld"
	buildPlaza(world)
	MapService.belt = buildConveyor(world)
	buildKiosks(world)
	for i = 1, #MapConfig.Bases do
		buildBase(world, i)
	end
	local creatures = Instance.new("Folder")
	creatures.Name = "Creatures"
	creatures.Parent = world
	MapService.creatureFolder = creatures
	local belt = Instance.new("Folder")
	belt.Name = "ConveyorItems"
	belt.Parent = world
	MapService.beltFolder = belt
	world.Parent = workspace
	MapService.world = world
end

function MapService.start() end

return MapService
