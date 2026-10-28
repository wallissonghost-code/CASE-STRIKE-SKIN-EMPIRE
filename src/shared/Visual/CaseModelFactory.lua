-- CaseModelFactory: modelo provisório de cada caixa (maleta com tampa, frisos e emblema).
-- Gerado por código, sem assets externos.

local CaseModelFactory = {}

local function c3(rgb)
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function part(model, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

function CaseModelFactory.build(caseDef)
	local model = Instance.new("Model")
	model.Name = caseDef.id .. "_case"
	local body = c3(caseDef.color)
	local trim = c3(caseDef.trim)
	local root = part(model, "Root", Vector3.new(3, 1.6, 2), CFrame.new(0, 0, 0), body)
	part(model, "Lid", Vector3.new(3.05, 0.35, 2.05), CFrame.new(0, 0.95, 0), body:Lerp(Color3.new(1, 1, 1), 0.12))
	part(model, "TrimFront", Vector3.new(3.1, 0.12, 0.08), CFrame.new(0, 0.75, -1.04), trim, Enum.Material.Neon)
	part(model, "TrimBack", Vector3.new(3.1, 0.12, 0.08), CFrame.new(0, 0.75, 1.04), trim, Enum.Material.Neon)
	part(model, "Latch", Vector3.new(0.5, 0.35, 0.12), CFrame.new(0, 0.5, -1.06), trim, Enum.Material.Metal)
	part(model, "Handle", Vector3.new(1.0, 0.18, 0.25), CFrame.new(0, 1.25, 0), trim, Enum.Material.Metal)
	local emblem = part(model, "Emblem", Vector3.new(0.9, 0.9, 0.06), CFrame.new(0, -0.1, -1.03), trim, Enum.Material.Neon)
	emblem.Shape = Enum.PartType.Block
	for _, x in ipairs({ -1.45, 1.45 }) do
		part(model, "Corner", Vector3.new(0.14, 1.65, 0.14), CFrame.new(x, 0, -1.0), trim, Enum.Material.Metal)
		part(model, "Corner", Vector3.new(0.14, 1.65, 0.14), CFrame.new(x, 0, 1.0), trim, Enum.Material.Metal)
	end
	model.PrimaryPart = root
	model:SetAttribute("PlaceholderModel", true)
	return model
end

return CaseModelFactory
