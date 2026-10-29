-- CreatureModel: monta cada criatura só com peças do Roblox (sem malhas, texturas ou IDs externos).
-- build(speciesId, mutationId, opts) -> Model com PrimaryPart "Body".
-- opts.anchored (padrão true). Para carregar na cabeça de um jogador use anchored = false:
-- as peças são soldadas ao corpo e o corpo pode ser soldado ao personagem.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)

local CreatureModel = {}

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function part(model, props)
	local p = Instance.new("Part")
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = true
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = model
	return p
end

-- posição relativa ao centro do corpo
local function at(body, x, y, z)
	return body.CFrame * CFrame.new(x, y, z)
end

local function eyes(model, body, r, spread, height, big)
	local size = big and r * 0.55 or r * 0.32
	for _, side in ipairs({ -1, 1 }) do
		part(model, { Name = "EyeWhite", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), Color = Color3.new(1, 1, 1), CFrame = at(body, side * spread, height, -r * 0.42) })
		part(model, { Name = "Pupil", Shape = Enum.PartType.Ball, Size = Vector3.new(size * 0.5, size * 0.5, size * 0.5), Color = Color3.fromRGB(20, 20, 30), CFrame = at(body, side * spread, height, -r * 0.42 - size * 0.38) })
	end
end

local builders = {}

builders.blob = function(model, body, r, color)
	body.Size = Vector3.new(r * 1.15, r * 0.85, r * 1.15)
	eyes(model, body, r, r * 0.22, r * 0.12)
end

builders.drop = function(model, body, r, color)
	body.Size = Vector3.new(r, r, r)
	part(model, { Name = "Tip", Size = Vector3.new(r * 0.45, r * 0.6, r * 0.45), Color = color, CFrame = at(body, 0, r * 0.55, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)) })
	eyes(model, body, r, r * 0.2, 0)
end

builders.spikes = function(model, body, r, color)
	body.Size = Vector3.new(r, r, r)
	for i = 0, 5 do
		local a = math.rad(i * 60)
		part(model, { Name = "Spike", Size = Vector3.new(r * 0.22, r * 0.55, r * 0.22), Color = color:Lerp(Color3.new(1, 1, 1), 0.35), CFrame = at(body, math.cos(a) * r * 0.42, r * 0.38, math.sin(a) * r * 0.42) * CFrame.Angles(math.sin(a) * 0.6, 0, -math.cos(a) * 0.6) })
	end
	eyes(model, body, r, r * 0.2, 0)
end

builders.tentacles = function(model, body, r, color)
	body.Size = Vector3.new(r, r * 0.9, r)
	for i = 0, 3 do
		local a = math.rad(45 + i * 90)
		part(model, { Name = "Tentacle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(r * 0.7, r * 0.2, r * 0.2), Color = color, CFrame = at(body, math.cos(a) * r * 0.4, -r * 0.45, math.sin(a) * r * 0.4) * CFrame.Angles(0, -a, math.rad(70)) })
	end
	eyes(model, body, r, r * 0.2, r * 0.1)
end

builders.ghost = function(model, body, r, color)
	body.Size = Vector3.new(r, r, r)
	part(model, { Name = "Tail", Size = Vector3.new(r * 0.9, r * 0.6, r * 0.9), Color = color, Transparency = 0.15, CFrame = at(body, 0, -r * 0.45, 0) })
	body.Transparency = 0.1
	eyes(model, body, r, r * 0.2, r * 0.1, true)
end

builders.mushroom = function(model, body, r, color)
	body.Size = Vector3.new(r * 0.8, r * 0.8, r * 0.8)
	body.Color = Color3.fromRGB(245, 235, 210)
	local cap = part(model, { Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 1.5, r * 0.8, r * 1.5), Color = color, CFrame = at(body, 0, r * 0.45, 0) })
	for i = 0, 3 do
		local a = math.rad(i * 90 + 20)
		part(model, { Name = "Dot", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.22, r * 0.12, r * 0.22), Color = Color3.new(1, 1, 1), CFrame = cap.CFrame * CFrame.new(math.cos(a) * r * 0.42, r * 0.3, math.sin(a) * r * 0.42) })
	end
	eyes(model, body, r * 0.8, r * 0.16, 0)
end

builders.eye = function(model, body, r, color)
	body.Size = Vector3.new(r, r, r)
	part(model, { Name = "BigEye", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.75, r * 0.75, r * 0.75), Color = Color3.new(1, 1, 1), CFrame = at(body, 0, r * 0.05, -r * 0.2) })
	part(model, { Name = "Iris", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.38, r * 0.38, r * 0.38), Color = color:Lerp(Color3.new(0, 0, 0), 0.4), CFrame = at(body, 0, r * 0.05, -r * 0.5) })
end

builders.dragon = function(model, body, r, color)
	body.Size = Vector3.new(r, r * 0.9, r * 1.2)
	for _, side in ipairs({ -1, 1 }) do
		part(model, { Name = "Wing", Size = Vector3.new(r * 0.9, r * 0.08, r * 0.6), Color = color:Lerp(Color3.new(0, 0, 0), 0.25), CFrame = at(body, side * r * 0.7, r * 0.25, 0) * CFrame.Angles(0, 0, side * 0.5) })
		part(model, { Name = "Horn", Size = Vector3.new(r * 0.12, r * 0.4, r * 0.12), Color = Color3.fromRGB(250, 240, 210), CFrame = at(body, side * r * 0.22, r * 0.5, -r * 0.15) * CFrame.Angles(0, 0, -side * 0.3) })
	end
	part(model, { Name = "Tail", Size = Vector3.new(r * 0.2, r * 0.2, r * 0.8), Color = color, CFrame = at(body, 0, -r * 0.1, r * 0.8) * CFrame.Angles(0.4, 0, 0) })
	eyes(model, body, r, r * 0.2, r * 0.1)
end

builders.cyclops = function(model, body, r, color)
	body.Size = Vector3.new(r, r * 1.1, r)
	part(model, { Name = "BigEye", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.5, r * 0.5, r * 0.5), Color = Color3.new(1, 1, 1), CFrame = at(body, 0, r * 0.15, -r * 0.33) })
	part(model, { Name = "Iris", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.24, r * 0.24, r * 0.24), Color = Color3.fromRGB(20, 20, 30), CFrame = at(body, 0, r * 0.15, -r * 0.55) })
	part(model, { Name = "Horn", Size = Vector3.new(r * 0.16, r * 0.5, r * 0.16), Color = Color3.fromRGB(250, 240, 210), CFrame = at(body, 0, r * 0.65, 0) })
end

builders.octopus = function(model, body, r, color)
	body.Size = Vector3.new(r, r * 1.1, r)
	for i = 0, 7 do
		local a = math.rad(i * 45)
		part(model, { Name = "Arm", Shape = Enum.PartType.Cylinder, Size = Vector3.new(r * 0.8, r * 0.16, r * 0.16), Color = color, CFrame = at(body, math.cos(a) * r * 0.45, -r * 0.5, math.sin(a) * r * 0.45) * CFrame.Angles(0, -a, math.rad(60)) })
	end
	eyes(model, body, r, r * 0.22, r * 0.05, true)
end

builders.crown = function(model, body, r, color)
	body.Size = Vector3.new(r * 1.2, r * 0.95, r * 1.2)
	local gold = Color3.fromRGB(255, 205, 60)
	part(model, { Name = "CrownBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(r * 0.25, r * 0.7, r * 0.7), Color = gold, Material = Enum.Material.Metal, CFrame = at(body, 0, r * 0.52, 0) * CFrame.Angles(0, 0, math.rad(90)) })
	for i = 0, 4 do
		local a = math.rad(i * 72)
		part(model, { Name = "CrownTip", Size = Vector3.new(r * 0.12, r * 0.28, r * 0.12), Color = gold, Material = Enum.Material.Metal, CFrame = at(body, math.cos(a) * r * 0.3, r * 0.72, math.sin(a) * r * 0.3) })
	end
	eyes(model, body, r, r * 0.24, r * 0.05)
end

builders.phoenix = function(model, body, r, color)
	body.Size = Vector3.new(r * 0.9, r, r * 0.9)
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			part(model, { Name = "Feather", Size = Vector3.new(r * (0.9 - k * 0.2), r * 0.08, r * 0.3), Color = color:Lerp(Color3.fromRGB(255, 230, 80), k * 0.35), Material = Enum.Material.Neon, CFrame = at(body, side * r * (0.6 + k * 0.1), r * (0.1 + k * 0.18), k * r * 0.15) * CFrame.Angles(0, 0, side * (0.5 + k * 0.2)) })
		end
	end
	part(model, { Name = "Crest", Size = Vector3.new(r * 0.1, r * 0.45, r * 0.3), Color = Color3.fromRGB(255, 230, 80), Material = Enum.Material.Neon, CFrame = at(body, 0, r * 0.6, 0) })
	eyes(model, body, r, r * 0.18, r * 0.12)
end

builders.titan = function(model, body, r, color)
	body.Shape = Enum.PartType.Block
	body.Size = Vector3.new(r * 1.1, r * 1.1, r * 0.9)
	body.Material = Enum.Material.DiamondPlate
	for _, side in ipairs({ -1, 1 }) do
		part(model, { Name = "Arm", Size = Vector3.new(r * 0.35, r * 0.9, r * 0.35), Color = color:Lerp(Color3.new(0, 0, 0), 0.2), Material = Enum.Material.DiamondPlate, CFrame = at(body, side * r * 0.75, -r * 0.1, 0) })
	end
	part(model, { Name = "Visor", Size = Vector3.new(r * 0.8, r * 0.18, r * 0.1), Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon, CFrame = at(body, 0, r * 0.2, -r * 0.47) })
end

builders.core = function(model, body, r, color)
	body.Size = Vector3.new(r * 0.8, r * 0.8, r * 0.8)
	body.Material = Enum.Material.Neon
	for i = 0, 2 do
		local ring = part(model, { Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(r * 0.08, r * 1.3, r * 1.3), Color = color:Lerp(Color3.new(1, 1, 1), 0.3), Material = Enum.Material.Glass, Transparency = 0.3, CFrame = body.CFrame * CFrame.Angles(math.rad(i * 60), math.rad(i * 40), 0) })
		ring.CastShadow = false
	end
end

-- aplica a aparência da mutação ao corpo (e às partes coloridas)
local function applyMutation(model, body, mutationId)
	local m = GameConfig.Mutations[mutationId]
	if not m or mutationId == "normal" then
		return
	end
	local color = rgb(m.color)
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "EyeWhite" and p.Name ~= "Pupil" and p.Name ~= "Iris" and p.Name ~= "BigEye" then
			if mutationId == "dourada" then
				p.Color = color
				p.Material = Enum.Material.Foil
				p.Reflectance = 0.25
			elseif mutationId == "diamante" then
				p.Color = color
				p.Material = Enum.Material.Glass
				p.Transparency = math.max(p.Transparency, 0.2)
				p.Reflectance = 0.35
			elseif mutationId == "radioativa" then
				p.Color = p.Color:Lerp(color, 0.7)
				p.Material = Enum.Material.Neon
			elseif mutationId == "vazio" then
				p.Color = Color3.fromRGB(40, 15, 70)
				p.Material = Enum.Material.Neon
			elseif mutationId == "arcoiris" then
				p.Material = Enum.Material.Neon
			end
		end
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = mutationId == "dourada" and 0.6 or 1.2
	light.Parent = body
	if mutationId == "arcoiris" then
		model:SetAttribute("Rainbow", true) -- o cliente anima as cores
	end
	if mutationId == "vazio" or mutationId == "arcoiris" or mutationId == "radioativa" then
		local sparkles = Instance.new("ParticleEmitter") -- textura padrão do Roblox, sem ID externo
		sparkles.Rate = 6
		sparkles.Lifetime = NumberRange.new(0.6, 1.2)
		sparkles.Speed = NumberRange.new(1, 2)
		sparkles.Size = NumberSequence.new(0.25)
		sparkles.Color = ColorSequence.new(color)
		sparkles.LightEmission = 0.8
		sparkles.Parent = body
	end
end

function CreatureModel.size(speciesId)
	local s = GameConfig.SpeciesById[speciesId]
	local tier = s and GameConfig.tier(s.rarity) or 1
	return 2.2 + tier * 0.55
end

function CreatureModel.build(speciesId, mutationId, opts)
	opts = opts or {}
	local s = GameConfig.SpeciesById[speciesId]
	local model = Instance.new("Model")
	model.Name = s and s.name or "Criatura"
	local r = CreatureModel.size(speciesId)
	local color = s and rgb(s.color) or Color3.new(0.5, 0.5, 0.5)
	local body = part(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(r, r, r), Color = color, CFrame = CFrame.new(0, 0, 0) })
	model.PrimaryPart = body
	local b = builders[s and s.shape or "blob"] or builders.blob
	b(model, body, r, color)
	applyMutation(model, body, mutationId)
	local anchored = opts.anchored ~= false
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			p.Anchored = anchored
			p.Massless = true
			if not anchored and p ~= body then
				local w = Instance.new("WeldConstraint")
				w.Part0 = body
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	model:SetAttribute("SpeciesId", speciesId)
	model:SetAttribute("MutationId", mutationId)
	return model
end

return CreatureModel
