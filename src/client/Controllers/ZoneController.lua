-- ZoneController: painel de Zonas, aviso grande ao entrar numa zona ("Zona 3 + 5% Sorte")
-- e barreiras LOCAIS nas zonas ainda bloqueadas (só para este jogador).
-- A zona atual vem do servidor (atributo ZoneId); a sorte só vale com a zona comprada.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ZoneConfig = require(Shared.Config.ZoneConfig)
local Format = require(Shared.Util.Format)

local UI = require(script.Parent.UIController)
local Net = require(script.Parent.Parent.Util.Net)
local Store = require(script.Parent.Parent.Util.Store)

local Zones = {}

local player = Players.LocalPlayer
local barrierFolder = nil
local barrierKey = nil
local banner = nil

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- paredes translúcidas em volta das zonas bloqueadas (colisão só no cliente deste jogador)
local function refreshBarriers(view)
	local parts = {}
	for _, z in ipairs(view.zones) do
		table.insert(parts, z.id .. (z.owned and "1" or "0"))
	end
	local key = table.concat(parts, ",")
	if key == barrierKey then
		return
	end
	barrierKey = key
	if barrierFolder then
		barrierFolder:Destroy()
	end
	barrierFolder = Instance.new("Folder")
	barrierFolder.Name = "LocalZoneBarriers"
	for _, z in ipairs(view.zones) do
		local cfg = ZoneConfig.ById[z.id]
		if cfg.area and not z.owned then
			local a = cfg.area
			local cx, cz, sx, sz = a.center[1], a.center[2], a.size[1], a.size[2]
			local walls = {
				{ Vector3.new(cx, 6, cz - sz / 2), Vector3.new(sx, 12, 1) },
				{ Vector3.new(cx, 6, cz + sz / 2), Vector3.new(sx, 12, 1) },
				{ Vector3.new(cx - sx / 2, 6, cz), Vector3.new(1, 12, sz) },
				{ Vector3.new(cx + sx / 2, 6, cz), Vector3.new(1, 12, sz) },
			}
			for _, w in ipairs(walls) do
				local p = Instance.new("Part")
				p.Anchored = true
				p.Size = w[2]
				p.CFrame = CFrame.new(w[1])
				p.Material = Enum.Material.ForceField
				p.Color = rgb(cfg.color)
				p.Transparency = 0.2
				p.CanCollide = true
				p.Parent = barrierFolder
			end
		end
	end
	barrierFolder.Parent = workspace
end

local function showBanner(zoneId)
	local cfg = ZoneConfig.ById[zoneId]
	if not cfg or not banner then
		return
	end
	local owned = false
	for _, z in ipairs(Store.view and Store.view.zones or {}) do
		if z.id == zoneId then
			owned = z.owned
		end
	end
	banner.Text = cfg.name .. (cfg.luck > 0 and ("\n+ " .. math.floor(cfg.luck * 100 + 0.5) .. "% Sorte" .. (owned and "" or " (bloqueada)")) or "")
	banner.TextColor3 = rgb(cfg.color)
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.2
	banner.Visible = true
	task.delay(2.5, function()
		TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

local function build()
	local p = UI.createPanel("🗺️ Zonas do Mapa", 820, 560, "Zones")
	local list = UI.scroll({ Size = UDim2.fromScale(1, 1), Parent = p.content })
	UI.list(list, 8)
	return {
		frame = p.frame,
		refresh = function(view)
			UI.clear(list)
			UI.text({
				Text = "Cada zona desbloqueada dá sorte extra enquanto você estiver DENTRO dela. Você está em: <b>" .. (ZoneConfig.ById[view.zone] and ZoneConfig.ById[view.zone].name or "—") .. "</b>",
				TextSize = 14,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, -8, 0, 0),
				LayoutOrder = 0,
				Parent = list,
			})
			for i, z in ipairs(view.zones) do
				local cfg = ZoneConfig.ById[z.id]
				local f = UI.frame({ BackgroundColor3 = UI.Theme.panel2:Lerp(rgb(cfg.color), 0.18), Size = UDim2.new(1, -8, 0, 78), LayoutOrder = i, Parent = list })
				UI.corner(f, 12)
				UI.text({ Text = z.name .. (z.luck > 0 and ("  <font color='#7CE08F'>+" .. math.floor(z.luck * 100 + 0.5) .. "% sorte</font>") or ""), Font = UI.Fonts.bold, TextSize = 16, Size = UDim2.new(1, -170, 0, 22), Position = UDim2.fromOffset(12, 8), Parent = f })
				local req = {}
				if z.cost > 0 then
					table.insert(req, "₵ " .. Format.int(z.cost))
				end
				if z.requiredLevel > 1 then
					table.insert(req, "nível " .. z.requiredLevel)
				end
				if z.requires then
					table.insert(req, "depois de " .. ZoneConfig.ById[z.requires].name)
				end
				UI.text({ Text = z.owned and "✔ Desbloqueada" or ("Requer: " .. table.concat(req, " • ")), TextSize = 13, TextColor3 = z.owned and UI.Theme.good or UI.Theme.muted, Size = UDim2.new(1, -170, 0, 18), Position = UDim2.fromOffset(12, 34), Parent = f })
				if not z.owned then
					local prevOk = true
					if z.requires then
						for _, o in ipairs(view.zones) do
							if o.id == z.requires then
								prevOk = o.owned
							end
						end
					end
					local btn = UI.button({
						Text = "Desbloquear",
						color = UI.Theme.accent,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -12, 0.5, 0),
						Size = UDim2.fromOffset(140, 42),
						Parent = f,
						onClick = function()
							UI.handle(Net.call("ProgressionAction", { action = "buyZone", zoneId = z.id }), z.name .. " desbloqueada!")
						end,
					})
					UI.setEnabled(btn, prevOk and view.level >= z.requiredLevel and view.credits >= z.cost, UI.Theme.accent)
				end
			end
		end,
	}
end

function Zones.init()
	UI.register("Zones", build)
	banner = UI.text({
		Name = "ZoneBanner",
		Font = UI.Fonts.title,
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 86),
		Size = UDim2.fromOffset(700, 110),
		Visible = false,
		Parent = UI.layers.HUD,
	})
	Store.changed:Connect(refreshBarriers)
	local last = player:GetAttribute("ZoneId")
	player:GetAttributeChangedSignal("ZoneId"):Connect(function()
		local z = player:GetAttribute("ZoneId")
		if z ~= last then
			last = z
			showBanner(z)
		end
	end)
end

return Zones
