-- LobbyService: constrói o lobby estilizado por código (peças simples, otimizado para celular).
-- Praça central, caminhos, vegetação e prédios com atalhos (ProximityPrompt) para os painéis.
-- A Arena de Batalha aparece bloqueada com "EM BREVE".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage.Shared
local CaseDefinitions = require(Shared.Config.CaseDefinitions)
local CaseModelFactory = require(Shared.Visual.CaseModelFactory)
local FeatureFlags = require(Shared.Config.FeatureFlags)

local LobbyService = {}

local root
local rand = Random.new(20261028) -- layout determinístico

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = props.Material or Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		if k ~= "ClassName" and k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = props.Parent or root
	return p
end

local function sign(parent, text, color, offsetY)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 60)
	bb.StudsOffset = Vector3.new(0, offsetY or 0, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = bb
	bb.Parent = parent
	return bb
end

local function prompt(parent, actionText, panel)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = actionText
	pp.ObjectText = ""
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp:SetAttribute("OpenPanel", panel)
	pp.Parent = parent
	return pp
end

local function tree(pos, scale)
	local trunkH = 6 * scale
	part({
		Name = "Trunk",
		Size = Vector3.new(1.4 * scale, trunkH, 1.4 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)),
		Color = Color3.fromRGB(120, 80, 50),
		Material = Enum.Material.Wood,
	})
	local leafColors = { Color3.fromRGB(80, 180, 90), Color3.fromRGB(60, 160, 80), Color3.fromRGB(110, 200, 100) }
	part({
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 7, 7) * scale,
		CFrame = CFrame.new(pos + Vector3.new(0, trunkH + 2.2 * scale, 0)),
		Color = leafColors[rand:NextInteger(1, #leafColors)],
		Material = Enum.Material.Grass,
		CanCollide = false,
	})
end

local function bush(pos)
	part({
		Name = "Bush",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3.5, 2.6, 3.5),
		CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)),
		Color = Color3.fromRGB(70, 170, 80),
		Material = Enum.Material.Grass,
		CanCollide = false,
	})
end

local function building(name, pos, size, wall, roof, label, panel, actionText)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = root
	part({ Name = "Walls", Size = size, CFrame = CFrame.new(pos + Vector3.new(0, size.Y / 2, 0)), Color = wall, Parent = model })
	part({
		Name = "Roof",
		Size = Vector3.new(size.X + 2, 1.5, size.Z + 2),
		CFrame = CFrame.new(pos + Vector3.new(0, size.Y + 0.75, 0)),
		Color = roof,
		Parent = model,
	})
	-- porta voltada para a praça (centro)
	local toCenter = (Vector3.new(0, 0, 0) - pos) * Vector3.new(1, 0, 1)
	local dir = toCenter.Magnitude > 0 and toCenter.Unit or Vector3.new(0, 0, -1)
	local doorPos = pos + dir * (size.Z / 2 + 0.3) + Vector3.new(0, 3.5, 0)
	local door = part({
		Name = "Door",
		Size = Vector3.new(5, 7, 0.6),
		CFrame = CFrame.lookAt(doorPos, doorPos + dir),
		Color = roof:Lerp(Color3.new(0, 0, 0), 0.25),
		Parent = model,
	})
	local pad = part({
		Name = "Pad",
		Size = Vector3.new(7, 0.3, 5),
		CFrame = CFrame.lookAt(pos + dir * (size.Z / 2 + 3) + Vector3.new(0, 0.15, 0), pos + dir * (size.Z / 2 + 10) + Vector3.new(0, 0.15, 0)),
		Color = roof,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.3,
		Parent = model,
	})
	sign(door, label, Color3.new(1, 1, 1), 6.5)
	if panel then
		prompt(pad, actionText or "Abrir", panel)
	end
	return model
end

local function path(from, to, width)
	local mid = (from + to) / 2
	local len = (to - from).Magnitude
	part({
		Name = "Path",
		Size = Vector3.new(width, 0.2, len),
		CFrame = CFrame.lookAt(mid, to) + Vector3.new(0, 0.1, 0),
		Color = Color3.fromRGB(225, 205, 160),
		Material = Enum.Material.Sand,
	})
end

function LobbyService.init() end

function LobbyService.start()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 155)

	root = Instance.new("Folder")
	root.Name = "Lobby"
	root.Parent = workspace

	-- terreno
	part({ Name = "Ground", Size = Vector3.new(420, 2, 420), CFrame = CFrame.new(0, -1, 0), Color = Color3.fromRGB(100, 190, 90), Material = Enum.Material.Grass })
	part({ Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 64, 64), CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(235, 225, 200), Material = Enum.Material.Slate })
	part({ Name = "PlazaRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, 20, 20), CFrame = CFrame.new(0, 0.22, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 190, 60), Material = Enum.Material.Neon, CanCollide = false })

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(0, 0.45, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = root

	-- prédios em volta da praça
	local R = 58
	local spots = {
		{ "Loja", Vector3.new(0, 0, -R), Color3.fromRGB(255, 170, 60), Color3.fromRGB(200, 80, 50), "LOJA DE CAIXAS", "Shop", "Abrir caixas" },
		{ "Banco", Vector3.new(R, 0, -20), Color3.fromRGB(250, 235, 180), Color3.fromRGB(60, 140, 90), "BANCO DE SKINS", "Bank", "Abrir banco" },
		{ "Oficina", Vector3.new(-R, 0, -20), Color3.fromRGB(180, 200, 230), Color3.fromRGB(60, 90, 170), "OFICINA", "Upgrade", "Melhorar skins" },
		{ "Museu", Vector3.new(R, 0, 30), Color3.fromRGB(230, 220, 250), Color3.fromRGB(130, 80, 190), "ÍNDICE / MUSEU", "Index", "Ver coleções" },
		{ "Missoes", Vector3.new(-R, 0, 30), Color3.fromRGB(240, 240, 240), Color3.fromRGB(220, 60, 90), "MISSÕES", "Missions", "Ver missões" },
	}
	for _, s in ipairs(spots) do
		building(s[1], s[2], Vector3.new(22, 14, 16), s[3], s[4], s[5], s[6], s[7])
		path(Vector3.new(0, 0, 0), s[2], 8)
	end

	-- Arena de Batalha: bloqueada (EM BREVE)
	local arenaPos = Vector3.new(0, 0, R + 20)
	local arena = building("ArenaBloqueada", arenaPos, Vector3.new(30, 12, 18), Color3.fromRGB(90, 90, 100), Color3.fromRGB(50, 50, 60), "ARENA DE BATALHA\n" .. FeatureFlags.LockedLabel, nil)
	path(Vector3.new(0, 0, 0), arenaPos, 8)
	part({
		Name = "Barrier",
		Size = Vector3.new(14, 8, 1),
		CFrame = CFrame.new(arenaPos + Vector3.new(0, 4, -11)),
		Color = Color3.fromRGB(255, 70, 70),
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
		Parent = arena,
	})

	-- vitrine das caixas na praça (decorativa; a compra acontece na Loja)
	for i, caseDef in ipairs(CaseDefinitions.List) do
		local angle = (i - 1) / #CaseDefinitions.List * math.pi * 2
		local p = Vector3.new(math.cos(angle) * 22, 0, math.sin(angle) * 22)
		part({ Name = "Pedestal", Size = Vector3.new(4, 2.4, 4), CFrame = CFrame.new(p + Vector3.new(0, 1.2, 0)), Color = Color3.fromRGB(245, 240, 230), Material = Enum.Material.Marble })
		local model = CaseModelFactory.build(caseDef)
		model:PivotTo(CFrame.new(p + Vector3.new(0, 3.8, 0)) * CFrame.Angles(0, -angle + math.pi / 2, 0))
		model:SetAttribute("Spin", true)
		model.Parent = root
		local pp = prompt(model.PrimaryPart, "Ver " .. caseDef.name, "Shop")
		pp:SetAttribute("CaseId", caseDef.id)
		sign(model.PrimaryPart, caseDef.name, Color3.fromRGB(caseDef.trim[1], caseDef.trim[2], caseDef.trim[3]), 2.6)
	end

	-- fonte central
	part({ Name = "Fountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 10, 10), CFrame = CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Marble })
	part({ Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 8.6, 8.6), CFrame = CFrame.new(0, 1.55, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 180, 255), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
	spawn.CFrame = CFrame.new(0, 0.45, 9)

	-- vegetação (evita prédios e caminhos)
	local function blocked(pos)
		if pos.Magnitude < 40 then
			return true
		end
		for _, s in ipairs(spots) do
			if (pos - s[2]).Magnitude < 20 then
				return true
			end
		end
		if (pos - arenaPos).Magnitude < 24 then
			return true
		end
		return false
	end
	local placed = 0
	local tries = 0
	while placed < 55 and tries < 600 do
		tries = tries + 1
		local pos = Vector3.new(rand:NextNumber(-190, 190), 0, rand:NextNumber(-190, 190))
		if not blocked(pos) then
			placed = placed + 1
			if placed % 3 == 0 then
				bush(pos)
			else
				tree(pos, rand:NextNumber(0.8, 1.4))
			end
		end
	end

	-- cercas nas bordas para manter os jogadores na área
	for _, w in ipairs({
		{ Vector3.new(0, 4, 205), Vector3.new(420, 8, 2) },
		{ Vector3.new(0, 4, -205), Vector3.new(420, 8, 2) },
		{ Vector3.new(205, 4, 0), Vector3.new(2, 8, 420) },
		{ Vector3.new(-205, 4, 0), Vector3.new(2, 8, 420) },
	}) do
		part({ Name = "Fence", Size = w[2], CFrame = CFrame.new(w[1]), Transparency = 1 })
	end
end

return LobbyService
