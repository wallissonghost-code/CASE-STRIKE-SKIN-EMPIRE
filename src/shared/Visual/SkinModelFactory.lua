-- SkinModelFactory: MODELOS PROVISÓRIOS das skins, gerados por código a partir de peças básicas.
-- Não usa IDs de assets. Cada categoria tem uma silhueta própria, colorida pela paleta da skin.
-- Para publicação, substitua por modelos próprios ou licenciados mantendo a mesma interface:
--   SkinModelFactory.build(def, upgrades) -> Model (PrimaryPart = "Root")

local Shared = script.Parent.Parent

local SkinModelFactory = {}

local function c3(rgb)
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function part(model, name, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local function wedge(model, name, size, cframe, color, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Parent = model
	return p
end

-- eixo X = comprimento da arma (cano aponta para +X)
local builders = {}

builders.Pistol = function(m, col, mat)
	part(m, "Slide", Vector3.new(1.5, 0.32, 0.22), CFrame.new(0.1, 0.18, 0), col.primary, mat)
	part(m, "Frame", Vector3.new(1.2, 0.18, 0.2), CFrame.new(0.05, -0.05, 0), col.secondary, mat)
	part(m, "Grip", Vector3.new(0.34, 0.75, 0.2), CFrame.new(-0.35, -0.42, 0) * CFrame.Angles(0, 0, math.rad(-12)), col.secondary, mat)
	part(m, "Barrel", Vector3.new(0.25, 0.12, 0.12), CFrame.new(0.95, 0.2, 0), col.accent, mat, Enum.PartType.Cylinder)
	part(m, "Trigger", Vector3.new(0.18, 0.2, 0.08), CFrame.new(-0.05, -0.22, 0), col.accent, mat)
	return { accentParts = { "Barrel", "Trigger" }, length = 1.9 }
end

builders.SMG = function(m, col, mat)
	part(m, "Body", Vector3.new(1.9, 0.42, 0.26), CFrame.new(0, 0.12, 0), col.primary, mat)
	part(m, "Barrel", Vector3.new(0.6, 0.14, 0.14), CFrame.new(1.2, 0.18, 0), col.accent, mat, Enum.PartType.Cylinder)
	part(m, "Grip", Vector3.new(0.3, 0.7, 0.22), CFrame.new(-0.35, -0.4, 0) * CFrame.Angles(0, 0, math.rad(-10)), col.secondary, mat)
	part(m, "Mag", Vector3.new(0.24, 0.85, 0.18), CFrame.new(0.35, -0.48, 0) * CFrame.Angles(0, 0, math.rad(8)), col.secondary, mat)
	part(m, "Stock", Vector3.new(0.8, 0.22, 0.18), CFrame.new(-1.3, 0.05, 0), col.secondary, mat)
	part(m, "Sight", Vector3.new(0.5, 0.12, 0.12), CFrame.new(0.1, 0.4, 0), col.accent, mat)
	return { accentParts = { "Barrel", "Sight" }, length = 3.0 }
end

builders.Rifle = function(m, col, mat)
	part(m, "Receiver", Vector3.new(2.2, 0.48, 0.28), CFrame.new(0, 0.1, 0), col.primary, mat)
	part(m, "Handguard", Vector3.new(1.3, 0.36, 0.26), CFrame.new(1.7, 0.12, 0), col.secondary, mat)
	part(m, "Barrel", Vector3.new(0.9, 0.12, 0.12), CFrame.new(2.75, 0.14, 0), col.accent, mat, Enum.PartType.Cylinder)
	part(m, "Stock", Vector3.new(1.2, 0.42, 0.24), CFrame.new(-1.65, 0.0, 0), col.secondary, mat)
	part(m, "Grip", Vector3.new(0.3, 0.7, 0.22), CFrame.new(-0.5, -0.42, 0) * CFrame.Angles(0, 0, math.rad(-12)), col.secondary, mat)
	part(m, "Mag", Vector3.new(0.3, 0.95, 0.2), CFrame.new(0.4, -0.55, 0) * CFrame.Angles(0, 0, math.rad(14)), col.primary, mat)
	part(m, "Rail", Vector3.new(1.1, 0.1, 0.14), CFrame.new(0.3, 0.39, 0), col.accent, mat)
	return { accentParts = { "Barrel", "Rail" }, length = 4.8 }
end

builders.Sniper = function(m, col, mat)
	part(m, "Receiver", Vector3.new(1.8, 0.42, 0.26), CFrame.new(0, 0.1, 0), col.primary, mat)
	part(m, "Barrel", Vector3.new(2.6, 0.14, 0.14), CFrame.new(2.2, 0.14, 0), col.secondary, mat, Enum.PartType.Cylinder)
	part(m, "Muzzle", Vector3.new(0.3, 0.2, 0.2), CFrame.new(3.55, 0.14, 0), col.accent, mat)
	part(m, "Stock", Vector3.new(1.5, 0.5, 0.24), CFrame.new(-1.6, -0.05, 0), col.secondary, mat)
	part(m, "Grip", Vector3.new(0.3, 0.65, 0.22), CFrame.new(-0.55, -0.4, 0) * CFrame.Angles(0, 0, math.rad(-14)), col.secondary, mat)
	part(m, "Scope", Vector3.new(1.3, 0.24, 0.24), CFrame.new(0.2, 0.5, 0), col.accent, mat, Enum.PartType.Cylinder)
	part(m, "ScopeMount", Vector3.new(0.5, 0.14, 0.14), CFrame.new(0.2, 0.35, 0), col.primary, mat)
	return { accentParts = { "Muzzle", "Scope" }, length = 5.4 }
end

builders.Knife = function(m, col, mat)
	part(m, "Blade", Vector3.new(1.3, 0.3, 0.06), CFrame.new(0.55, 0.0, 0), col.primary, Enum.Material.Metal)
	wedge(m, "Tip", Vector3.new(0.06, 0.3, 0.4), CFrame.new(1.4, 0.0, 0) * CFrame.Angles(0, math.rad(90), 0), col.primary, Enum.Material.Metal)
	part(m, "Edge", Vector3.new(1.3, 0.06, 0.07), CFrame.new(0.55, -0.15, 0), col.accent, mat)
	part(m, "Guard", Vector3.new(0.12, 0.5, 0.16), CFrame.new(-0.15, 0, 0), col.accent, mat)
	part(m, "Handle", Vector3.new(0.85, 0.22, 0.18), CFrame.new(-0.62, -0.02, 0), col.secondary, mat)
	part(m, "Pommel", Vector3.new(0.14, 0.26, 0.2), CFrame.new(-1.08, -0.02, 0), col.accent, mat)
	return { accentParts = { "Edge", "Guard", "Pommel" }, length = 2.6 }
end

local function addPattern(m, pattern, color, length)
	if pattern == "stripes" then
		for i = -1, 1 do
			part(m, "Stripe", Vector3.new(0.06, 0.5, 0.3), CFrame.new(i * length * 0.18, 0.1, 0), color)
		end
	elseif pattern == "bands" then
		part(m, "Band", Vector3.new(length * 0.55, 0.08, 0.3), CFrame.new(0, 0.22, 0), color)
	elseif pattern == "panels" then
		part(m, "PanelL", Vector3.new(length * 0.25, 0.22, 0.02), CFrame.new(-length * 0.05, 0.1, 0.15), color)
		part(m, "PanelR", Vector3.new(length * 0.25, 0.22, 0.02), CFrame.new(-length * 0.05, 0.1, -0.15), color)
	end
end

function SkinModelFactory.build(def, upgrades)
	upgrades = upgrades or {}
	local v = def.visual
	local col = {
		primary = c3(v.primary),
		secondary = c3(v.secondary),
		accent = c3(v.accent),
	}
	if upgrades.variant then
		col.primary, col.secondary = col.secondary, col.primary
	end
	local mat = upgrades.finish and Enum.Material.Metal or Enum.Material.SmoothPlastic

	local model = Instance.new("Model")
	model.Name = def.id
	local builder = builders[def.category] or builders.Rifle
	local info = builder(model, col, mat)
	if def.category ~= "Knife" then
		addPattern(model, v.pattern, col.accent, info.length)
	end

	local glow = v.glow or upgrades.glow
	for _, name in ipairs(info.accentParts) do
		local p = model:FindFirstChild(name)
		if p and glow then
			p.Material = Enum.Material.Neon
		end
	end
	if upgrades.finish then
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") and p.Material ~= Enum.Material.Neon then
				p.Reflectance = 0.15
			end
		end
	end

	-- raiz invisível no centro (usada para girar e para soldar no personagem)
	local cf, size = model:GetBoundingBox()
	local root = part(model, "Root", Vector3.new(0.2, 0.2, 0.2), cf, col.primary)
	root.Transparency = 1
	model.PrimaryPart = root
	if glow then
		local light = Instance.new("PointLight")
		light.Color = col.accent
		light.Brightness = 1.2
		light.Range = math.max(4, size.Magnitude)
		light.Parent = root
	end

	-- marca de provisório (verificável antes da publicação)
	model:SetAttribute("PlaceholderModel", v.placeholderModel == true)
	model:SetAttribute("SkinId", def.id)
	return model
end

-- Converte um modelo ancorado em montagem soldada (para exibir no personagem).
function SkinModelFactory.weldAssembly(model)
	local root = model.PrimaryPart
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			if p ~= root then
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = p
				w.Parent = p
			end
			p.Anchored = false
		end
	end
	return model
end

return SkinModelFactory
