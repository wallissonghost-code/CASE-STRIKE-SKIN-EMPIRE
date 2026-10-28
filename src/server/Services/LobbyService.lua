-- LobbyService: constrói o lobby estilizado por código (peças simples, otimizado para celular).
-- Mapa compacto: praça central com spawn e vitrine das 12 caixas; loja, banco, oficina, museu
-- (índice), missões e área de recompensas em volta; showroom de vitrines dos jogadores;
-- painel de rankings; portais de futuras atualizações bloqueados com "EM BREVE".

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

local function rock(pos, scale)
	local colors = { Color3.fromRGB(150, 150, 160), Color3.fromRGB(125, 128, 140), Color3.fromRGB(170, 165, 155) }
	part({
		Name = "Rock",
		Size = Vector3.new(3.2, 2.2, 2.6) * scale,
		CFrame = CFrame.new(pos + Vector3.new(0, 0.8 * scale, 0)) * CFrame.Angles(rand:NextNumber(-0.3, 0.3), rand:NextNumber(0, 6.28), rand:NextNumber(-0.3, 0.3)),
		Color = colors[rand:NextInteger(1, #colors)],
		Material = Enum.Material.Slate,
	})
end

-- portal de atualização futura: arco neon com barreira e placa "EM BREVE"
local function portal(name, pos, facing, color)
	local model = Instance.new("Model")
	model.Name = "Portal_" .. name
	model.Parent = root
	local cf = CFrame.lookAt(pos, pos + facing)
	part({ Name = "PillarL", Size = Vector3.new(1.6, 14, 1.6), CFrame = cf * CFrame.new(-6, 7, 0), Color = Color3.fromRGB(60, 60, 75), Material = Enum.Material.Slate, Parent = model })
	part({ Name = "PillarR", Size = Vector3.new(1.6, 14, 1.6), CFrame = cf * CFrame.new(6, 7, 0), Color = Color3.fromRGB(60, 60, 75), Material = Enum.Material.Slate, Parent = model })
	part({ Name = "Top", Size = Vector3.new(14, 1.6, 1.6), CFrame = cf * CFrame.new(0, 14, 0), Color = color, Material = Enum.Material.Neon, Parent = model })
	local field = part({ Name = "Field", Size = Vector3.new(10.4, 12.4, 0.4), CFrame = cf * CFrame.new(0, 7, 0), Color = color, Material = Enum.Material.ForceField, Transparency = 0.1, Parent = model })
	sign(field, name .. "\n" .. FeatureFlags.LockedLabel, Color3.new(1, 1, 1), 9)
	prompt(field, "Ver detalhes", "Battle")
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

	-- terreno e praça
	part({ Name = "Ground", Size = Vector3.new(640, 2, 640), CFrame = CFrame.new(0, -1, 0), Color = Color3.fromRGB(100, 190, 90), Material = Enum.Material.Grass })
	part({ Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 64, 64), CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(235, 225, 200), Material = Enum.Material.Slate })
	part({ Name = "PlazaRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, 20, 20), CFrame = CFrame.new(0, 0.22, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 190, 60), Material = Enum.Material.Neon, CanCollide = false })

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(0, 0.45, 9)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = root

	-- prédios em volta da praça
	local R = 58
	local spots = {
		{ "Loja", Vector3.new(0, 0, -R), Color3.fromRGB(255, 170, 60), Color3.fromRGB(200, 80, 50), "LOJA DE CAIXAS", "Shop", "Abrir caixas" },
		{ "Banco", Vector3.new(R, 0, -24), Color3.fromRGB(250, 235, 180), Color3.fromRGB(60, 140, 90), "BANCO DE SKINS", "Bank", "Abrir banco" },
		{ "Oficina", Vector3.new(-R, 0, -24), Color3.fromRGB(180, 200, 230), Color3.fromRGB(60, 90, 170), "OFICINA", "Upgrade", "Melhorar skins" },
		{ "Museu", Vector3.new(R, 0, 26), Color3.fromRGB(230, 220, 250), Color3.fromRGB(130, 80, 190), "ÍNDICE / MUSEU", "Collections", "Ver coleções" },
		{ "Missoes", Vector3.new(-R, 0, 26), Color3.fromRGB(240, 240, 240), Color3.fromRGB(220, 60, 90), "MISSÕES", "Missions", "Ver missões" },
		{ "Recompensas", Vector3.new(-30, 0, 58), Color3.fromRGB(255, 230, 240), Color3.fromRGB(235, 90, 150), "PRESENTES", "Gifts", "Resgatar presentes" },
	}
	for _, s in ipairs(spots) do
		building(s[1], s[2], Vector3.new(22, 14, 16), s[3], s[4], s[5], s[6], s[7])
		path(Vector3.new(0, 0, 0), s[2], 8)
	end

	-- painel de rankings (atualizado pelo LeaderboardService a partir do cache)
	local boardPos = Vector3.new(30, 0, 58)
	local board = part({
		Name = "RankingBoard",
		Size = Vector3.new(18, 12, 1),
		CFrame = CFrame.lookAt(boardPos + Vector3.new(0, 7, 0), Vector3.new(0, 7, 0)),
		Color = Color3.fromRGB(30, 34, 52),
		Material = Enum.Material.SmoothPlastic,
	})
	part({ Name = "RankingFrame", Size = Vector3.new(19, 13, 0.6), CFrame = board.CFrame * CFrame.new(0, 0, 0.5), Color = Color3.fromRGB(255, 176, 46), Material = Enum.Material.Neon, CanCollide = false })
	local surface = Instance.new("SurfaceGui")
	surface.Name = "RankingGui"
	surface.Face = Enum.NormalId.Front
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.Parent = board
	local list = Instance.new("TextLabel")
	list.Name = "Rows"
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.TextColor3 = Color3.new(1, 1, 1)
	list.Font = Enum.Font.GothamBold
	list.TextSize = 30
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "🏆 PATRIMÔNIO\nCarregando..."
	list.Parent = surface
	prompt(board, "Ver rankings", "Leaderboard")
	path(Vector3.new(0, 0, 0), boardPos, 6)

	-- showroom: pavilhão aberto com 12 vitrines (uma por jogador, visitáveis)
	local showroom = Instance.new("Model")
	showroom.Name = "Showroom"
	showroom.Parent = root
	local center = Vector3.new(0, 0, 118)
	part({ Name = "Floor", Size = Vector3.new(92, 0.6, 62), CFrame = CFrame.new(center + Vector3.new(0, 0.3, 0)), Color = Color3.fromRGB(245, 242, 235), Material = Enum.Material.Marble, Parent = showroom })
	for _, x in ipairs({ -45, 45 }) do
		for _, z in ipairs({ -30, 0, 30 }) do
			part({ Name = "Column", Size = Vector3.new(2, 16, 2), CFrame = CFrame.new(center + Vector3.new(x, 8, z)), Color = Color3.fromRGB(230, 225, 215), Material = Enum.Material.Marble, Parent = showroom })
		end
	end
	part({ Name = "Roof", Size = Vector3.new(96, 1.2, 66), CFrame = CFrame.new(center + Vector3.new(0, 16.6, 0)), Color = Color3.fromRGB(70, 60, 110), Transparency = 0.15, Parent = showroom })
	local entrance = part({ Name = "Entrance", Size = Vector3.new(16, 0.3, 4), CFrame = CFrame.new(center + Vector3.new(0, 0.65, -33)), Color = Color3.fromRGB(160, 90, 245), Material = Enum.Material.Neon, CanCollide = false, Parent = showroom })
	sign(entrance, "SHOWROOM DE SKINS", Color3.new(1, 1, 1), 9)
	local boothFolder = Instance.new("Folder")
	boothFolder.Name = "Booths"
	boothFolder.Parent = showroom
	local n = 0
	for row = 0, 2 do
		for col = 0, 3 do
			n = n + 1
			local pos = center + Vector3.new(-33 + col * 22, 0.7, -18 + row * 19)
			local booth = part({
				Name = "Booth" .. n,
				Size = Vector3.new(19, 0.2, 14),
				CFrame = CFrame.new(pos),
				Color = Color3.fromRGB(225, 220, 245),
				Material = Enum.Material.SmoothPlastic,
				Parent = boothFolder,
			})
			booth:SetAttribute("Index", n)
		end
	end
	path(Vector3.new(0, 0, 0), center + Vector3.new(0, 0, -33), 10)

	-- portais de futuras atualizações (bloqueados)
	local portals = {
		{ "ARENA PVP", Vector3.new(96, 0, -30), Color3.fromRGB(255, 70, 70) },
		{ "MASMORRA DE MONSTROS", Vector3.new(96, 0, 0), Color3.fromRGB(120, 220, 90) },
		{ "TORRE DOS CHEFES", Vector3.new(96, 0, 30), Color3.fromRGB(255, 160, 40) },
		{ "MERCADO DE TROCAS", Vector3.new(-96, 0, 0), Color3.fromRGB(80, 170, 255) },
	}
	for _, pt in ipairs(portals) do
		local facing = (Vector3.new(0, 0, 0) - pt[2]) * Vector3.new(1, 0, 1)
		portal(pt[1], pt[2], facing.Unit, pt[3])
	end
	path(Vector3.new(0, 0, 0), Vector3.new(90, 0, 0), 6)
	path(Vector3.new(0, 0, 0), Vector3.new(-90, 0, 0), 6)

	-- vitrine das 12 caixas na praça (a compra acontece na Loja)
	for i, caseDef in ipairs(CaseDefinitions.Collections) do
		local angle = (i - 1) / #CaseDefinitions.Collections * math.pi * 2
		local p = Vector3.new(math.cos(angle) * 24, 0, math.sin(angle) * 24)
		part({ Name = "Pedestal", Size = Vector3.new(3.6, 2.2, 3.6), CFrame = CFrame.new(p + Vector3.new(0, 1.1, 0)), Color = Color3.fromRGB(245, 240, 230), Material = Enum.Material.Marble })
		local model = CaseModelFactory.build(caseDef)
		model:ScaleTo(0.8)
		model:PivotTo(CFrame.new(p + Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, -angle + math.pi / 2, 0))
		model:SetAttribute("Spin", true)
		model.Parent = root
		local pp = prompt(model.PrimaryPart, "Ver " .. caseDef.name, "Shop")
		pp:SetAttribute("CaseId", caseDef.id)
		sign(model.PrimaryPart, caseDef.name, Color3.fromRGB(caseDef.trim[1], caseDef.trim[2], caseDef.trim[3]), 2.4)
	end

	-- fonte central
	part({ Name = "Fountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 10, 10), CFrame = CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Marble })
	part({ Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 8.6, 8.6), CFrame = CFrame.new(0, 1.55, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 180, 255), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })

	-- vegetação e pedras (evitando prédios, caminhos, showroom e portais)
	local avoid = { { Vector3.new(0, 0, 0), 40 }, { boardPos, 14 }, { center, 56 } }
	for _, s in ipairs(spots) do
		table.insert(avoid, { s[2], 20 })
	end
	for _, pt in ipairs(portals) do
		table.insert(avoid, { pt[2], 14 })
	end
	local function blocked(pos)
		if math.abs(pos.X) > 170 or math.abs(pos.Z) > 170 then
			return true -- além disso ficam as zonas (decoradas pelo ZoneService)
		end
		for _, a in ipairs(avoid) do
			if (pos - a[1]).Magnitude < a[2] then
				return true
			end
		end
		-- caminhos principais em cruz
		if math.abs(pos.X) < 6 or math.abs(pos.Z) < 5 then
			return true
		end
		return false
	end
	local placed, tries = 0, 0
	while placed < 70 and tries < 900 do
		tries = tries + 1
		local pos = Vector3.new(rand:NextNumber(-165, 165), 0, rand:NextNumber(-165, 165))
		if not blocked(pos) then
			placed = placed + 1
			local kind = placed % 5
			if kind == 0 then
				rock(pos, rand:NextNumber(0.8, 1.8))
			elseif kind == 1 then
				bush(pos)
			else
				tree(pos, rand:NextNumber(0.8, 1.4))
			end
		end
	end

	-- cercas invisíveis nas bordas
	for _, w in ipairs({
		{ Vector3.new(0, 4, 310), Vector3.new(640, 8, 2) },
		{ Vector3.new(0, 4, -310), Vector3.new(640, 8, 2) },
		{ Vector3.new(310, 4, 0), Vector3.new(2, 8, 640) },
		{ Vector3.new(-310, 4, 0), Vector3.new(2, 8, 640) },
	}) do
		part({ Name = "Fence", Size = w[2], CFrame = CFrame.new(w[1]), Transparency = 1 })
	end
end

return LobbyService
