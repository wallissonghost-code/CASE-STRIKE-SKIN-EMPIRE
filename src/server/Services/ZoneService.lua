-- ZoneService: zonas do mapa com sorte extra (ZoneConfig).
-- * Constrói o chão, a decoração, a placa "+5% Sorte" e o portão de compra de cada zona.
-- * A cada segundo o SERVIDOR verifica em que zona está cada personagem e grava o atributo
--   "ZoneId" no jogador; a sorte da zona só vale se a zona estiver desbloqueada no perfil.
-- * As barreiras das zonas bloqueadas são desenhadas pelo cliente (só para quem não comprou);
--   atravessá-las por exploit não dá nada, porque o servidor exige a zona desbloqueada.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ZoneConfig = require(Shared.Config.ZoneConfig)
local ProfileOps = require(Shared.Logic.ProfileOps)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local Validate = require(script.Parent.Parent.Core.Validate)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ZoneService = {}

local CHECK_INTERVAL = 1
local rand = Random.new(4242)

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function part(parent, props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "ClassName" then
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function bigSign(parent, text, color)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(320, 90)
	bb.StudsOffset = Vector3.new(0, 10, 0)
	bb.MaxDistance = 220
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.2
	t.Parent = bb
	bb.Parent = parent
end

-- decoração temática leve (poucas peças por zona)
local DECOR = {
	zone2 = function(folder, x, z)
		local colors = { Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 220, 90), Color3.fromRGB(150, 120, 255) }
		part(folder, { Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(x, 1.2, z), Color = colors[rand:NextInteger(1, 3)], Material = Enum.Material.SmoothPlastic, CanCollide = false })
		part(folder, { Name = "Stem", Size = Vector3.new(0.3, 1, 0.3), CFrame = CFrame.new(x, 0.5, z), Color = Color3.fromRGB(60, 150, 60), CanCollide = false })
	end,
	zone3 = function(folder, x, z)
		part(folder, { Name = "Pumpkin", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2, 2.4), CFrame = CFrame.new(x, 1, z), Color = Color3.fromRGB(235, 120, 30), Material = Enum.Material.SmoothPlastic })
		part(folder, { Name = "DeadTree", Size = Vector3.new(1, 7, 1), CFrame = CFrame.new(x + 4, 3.5, z + 3) * CFrame.Angles(0, 0, 0.2), Color = Color3.fromRGB(60, 45, 50), Material = Enum.Material.Wood })
	end,
	zone4 = function(folder, x, z)
		part(folder, { Name = "Crystal", ClassName = "WedgePart", Size = Vector3.new(2, 6, 3), CFrame = CFrame.new(x, 3, z) * CFrame.Angles(0, rand:NextNumber(0, 6.28), 0), Color = Color3.fromRGB(120, 220, 255), Material = Enum.Material.Glass, Transparency = 0.2 })
	end,
}

local function buildZones()
	local lobby = workspace:WaitForChild("Lobby", 30)
	local root = Instance.new("Folder")
	root.Name = "Zones"
	root.Parent = lobby or workspace
	for _, zone in ipairs(ZoneConfig.Zones) do
		local a = zone.area
		if a then
			local folder = Instance.new("Model")
			folder.Name = zone.id
			folder:SetAttribute("ZoneId", zone.id)
			folder.Parent = root
			local cx, cz = a.center[1], a.center[2]
			local floor = part(folder, {
				Name = "Floor",
				Size = Vector3.new(a.size[1], 0.4, a.size[2]),
				CFrame = CFrame.new(cx, 0.2, cz),
				Color = rgb(zone.color):Lerp(Color3.fromRGB(90, 170, 90), 0.6),
				Material = Enum.Material.Grass,
			})
			floor:SetAttribute("ZoneId", zone.id)
			bigSign(floor, zone.name .. "\n+" .. math.floor(zone.luck * 100 + 0.5) .. "% Sorte", rgb(zone.color))
			-- portão (lado voltado para a praça) com o atalho de desbloqueio
			local toCenter = Vector3.new(-cx, 0, -cz).Unit
			local gatePos = Vector3.new(cx, 0, cz) + Vector3.new(toCenter.X * a.size[1] / 2, 0, toCenter.Z * a.size[2] / 2)
			local gate = part(folder, {
				Name = "Gate",
				Size = Vector3.new(14, 0.3, 8),
				CFrame = CFrame.new(gatePos + Vector3.new(0, 0.5, 0) + toCenter * 5),
				Color = rgb(zone.color),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Transparency = 0.3,
			})
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = "Desbloquear zona"
			pp.ObjectText = zone.name .. " • ₵ " .. tostring(zone.cost)
			pp.HoldDuration = 0
			pp.MaxActivationDistance = 14
			pp.RequiresLineOfSight = false
			pp:SetAttribute("OpenPanel", "Zones")
			pp.Parent = gate
			-- caminho até a praça
			local from = Vector3.new(toCenter.X * 100, 0, toCenter.Z * 100) * -1
			local mid = (from + gatePos) / 2
			part(folder, {
				Name = "Path",
				Size = Vector3.new(8, 0.2, (gatePos - from).Magnitude),
				CFrame = CFrame.lookAt(mid, gatePos) + Vector3.new(0, 0.1, 0),
				Color = Color3.fromRGB(225, 205, 160),
				Material = Enum.Material.Sand,
			})
			-- decoração
			local decor = DECOR[zone.id]
			if decor then
				for _ = 1, 18 do
					decor(folder, cx + rand:NextNumber(-a.size[1] / 2 + 6, a.size[1] / 2 - 6), cz + rand:NextNumber(-a.size[2] / 2 + 6, a.size[2] / 2 - 6))
				end
			end
		end
	end
end

local function trackPositions()
	while true do
		task.wait(CHECK_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local pos = root.Position
				local zoneId = ZoneConfig.zoneAt(pos.X, pos.Z)
				if player:GetAttribute("ZoneId") ~= zoneId then
					player:SetAttribute("ZoneId", zoneId)
					PlayerDataService.push(player) -- atualiza a sorte exibida
				end
			end
		end
	end
end

function ZoneService.init() end

function ZoneService.start()
	buildZones()
	task.spawn(trackPositions)

	Remotes.on("ProgressionAction", "buyZone", "Progression", function(player, payload)
		if not Validate.id(payload.zoneId, 24) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.buyZone(profile, ctx, payload.zoneId)
		end, { important = true })
	end)

	Remotes.on("ProgressionAction", "activatePotion", "Progression", function(player, payload)
		if not Validate.id(payload.potionId, 24) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.activatePotion(profile, ctx, payload.potionId)
		end, { important = true })
	end)
end

return ZoneService
