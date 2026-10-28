-- ProgressionService: renascimento (com confirmação inequívoca), atributos, títulos e a placa
-- acima do personagem (nome, título, nível e patrimônio resumido).
-- Níveis e XP são concedidos pela lógica de cada operação (Logic/Progression).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local ProfileOps = require(Shared.Logic.ProfileOps)
local Wealth = require(Shared.Logic.Wealth)
local Format = require(Shared.Util.Format)
local ProgressionConfig = require(Shared.Config.ProgressionConfig)
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local RarityConfig = require(Shared.Config.RarityConfig)
local SkinModelFactory = require(Shared.Visual.SkinModelFactory)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local Validate = require(script.Parent.Parent.Core.Validate)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ProgressionService = {}

-- placa acima do personagem: compacta, só atualiza quando o texto muda
local plateText = {}

local function plateLines(player, profile)
	local title = ProgressionConfig.Titles[profile.equippedTitle or ""]
	local rb = profile.rebirths > 0 and ("  ♻" .. profile.rebirths) or ""
	return player.DisplayName,
		(title and title.displayName or "") .. rb,
		"Nv " .. profile.level .. "  •  ₵ " .. Format.short(Wealth.netWorth(profile))
end

-- skin equipada de maior valor (exibida acima da cabeça, como vitrine pessoal)
local function topEquipped(profile)
	local best = nil
	for _, item in pairs(profile.inventory) do
		if item.equipped and item.location == "inventory" then
			local def = SkinDefinitions.ById[item.defId]
			if def and (not best or def.value > SkinDefinitions.ById[best.defId].value) then
				best = item
			end
		end
	end
	return best
end

local function refreshPlate(player)
	local profile = PlayerDataService.getProfile(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not profile or not head then
		return
	end
	local name, title, stats = plateLines(player, profile)
	local top = topEquipped(profile)
	local topKey = ""
	if top then
		local ups = {}
		for k in pairs(top.upgrades or {}) do
			table.insert(ups, k)
		end
		table.sort(ups)
		topKey = top.defId .. ":" .. table.concat(ups, ",")
	end
	local key = name .. "|" .. title .. "|" .. stats .. "|" .. topKey
	local gui = head:FindFirstChild("CollectorPlate")
	if gui and plateText[player] == key then
		return
	end
	plateText[player] = key
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "CollectorPlate"
		gui.Size = UDim2.fromOffset(200, 120)
		gui.StudsOffset = Vector3.new(0, 3.6, 0)
		gui.MaxDistance = 60
		gui.LightInfluence = 0
		gui.AlwaysOnTop = false
		local function label(n, y, h, size, color)
			local l = Instance.new("TextLabel")
			l.Name = n
			l.BackgroundTransparency = 1
			l.Size = UDim2.new(1, 0, 0, h)
			l.Position = UDim2.fromOffset(0, y)
			l.Font = Enum.Font.GothamBold
			l.TextSize = size
			l.TextColor3 = color
			l.TextStrokeTransparency = 0.4
			l.Parent = gui
			return l
		end
		local vp = Instance.new("ViewportFrame")
		vp.Name = "TopSkin"
		vp.BackgroundTransparency = 1
		vp.Size = UDim2.new(1, 0, 0, 44)
		vp.Ambient = Color3.fromRGB(190, 190, 200)
		vp.LightDirection = Vector3.new(-1, -1, -1)
		vp.Parent = gui
		label("SkinValue", 44, 14, 11, Color3.fromRGB(255, 220, 120))
		label("PlayerName", 60, 20, 16, Color3.new(1, 1, 1))
		label("Title", 79, 16, 12, Color3.fromRGB(255, 190, 70))
		label("Stats", 95, 16, 12, Color3.fromRGB(190, 230, 200))
		gui.Parent = head
		-- esconde o nome padrão do Roblox para não duplicar
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	gui.PlayerName.Text = name
	gui.Title.Text = title
	gui.Stats.Text = stats
	-- skin equipada de maior valor acima da cabeça
	local vp = gui.TopSkin
	for _, c in ipairs(vp:GetChildren()) do
		c:Destroy()
	end
	if top then
		local def = SkinDefinitions.ById[top.defId]
		local model = SkinModelFactory.build(def, top.upgrades)
		model:PivotTo(CFrame.new(0, 0, 0))
		model.Parent = vp
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		local _, size = model:GetBoundingBox()
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, size.Magnitude * 1.6), Vector3.new(0, 0, 0))
		cam.Parent = vp
		vp.CurrentCamera = cam
		local r = RarityConfig.Rarities[def.rarity]
		gui.SkinValue.Text = def.finish .. " • ₵ " .. Format.short(def.value)
		gui.SkinValue.TextColor3 = Color3.fromRGB(r.color[1], r.color[2], r.color[3])
	else
		gui.SkinValue.Text = ""
	end
end

function ProgressionService.init() end

function ProgressionService.start()
	PlayerDataService.onChanged(function(player)
		refreshPlate(player)
	end)
	PlayerDataService.onLoaded(function(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			plateText[player] = nil
			refreshPlate(player)
		end)
		refreshPlate(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		plateText[player] = nil
	end)

	Remotes.on("ProgressionAction", "rebirth", "Progression", function(player, payload)
		if type(payload.confirmPhrase) ~= "string" or #payload.confirmPhrase > 32 then
			return Remotes.fail("confirmation_required", ProfileOps.Messages.confirmation_required)
		end
		local response = PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.rebirth(profile, ctx, payload.confirmPhrase)
		end, { important = true })
		return response
	end)

	Remotes.on("ProgressionAction", "buyAttribute", "Progression", function(player, payload)
		if not Validate.id(payload.attributeId, 32) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.buyAttribute(profile, ctx, payload.attributeId)
		end, { important = true })
	end)

	Remotes.on("ProgressionAction", "setTitle", "Progression", function(player, payload)
		if not Validate.id(payload.titleId, 32) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.setTitle(profile, ctx, payload.titleId)
		end)
	end)
end

return ProgressionService
