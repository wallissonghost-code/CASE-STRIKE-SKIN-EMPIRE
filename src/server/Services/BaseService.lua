-- BaseService: bases dos jogadores.
-- * Distribui uma das 6 bases ao entrar e leva o personagem até ela.
-- * Mostra as criaturas nos pedestais (com o valor guardado atualizado a cada segundo).
-- * Coletar e travar a base só funcionam com o personagem DENTRO da própria base (o servidor confere).
-- * Escudo: lasers na entrada; quem não é dono e está dentro é empurrado para fora (sem dano).
-- * Velocidade de caminhada definida pelo servidor (melhorias, poção, carregando criatura).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local MapConfig = require(Shared.Config.MapConfig)
local ProfileOps = require(Shared.Logic.ProfileOps)
local ProfileSchema = require(Shared.Logic.ProfileSchema)
local Income = require(Shared.Logic.Income)
local Format = require(Shared.Util.Format)
local CreatureModel = require(Shared.Visual.CreatureModel)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local MapService = require(script.Parent.MapService)

local BaseService = {}

local owners = {} -- [baseIndex] = player
local baseOf = {} -- [player] = baseIndex
local shieldUntil = {} -- [baseIndex] = horário
local rendered = {} -- [player] = { [uid] = { model, label, pad, key } }
local hidden = {} -- [uid] = true (sendo carregada por alguém)
BaseService.promptHandlers = {} -- [nomeDoAtributo] = function(prompt, player)
BaseService.carryingProvider = nil -- function(player) -> info ou nil

local function rgbHex(t)
	return string.format("#%02X%02X%02X", t[1], t[2], t[3])
end

function BaseService.notify(player, kind, text, extra)
	local payload = { kind = kind, text = text }
	for k, v in pairs(extra or {}) do
		payload[k] = v
	end
	Remotes.event("Notify"):FireClient(player, payload)
end

function BaseService.notifyAll(kind, text)
	Remotes.event("Notify"):FireAllClients({ kind = kind, text = text })
end

---------------------------------------------------------------------------
-- posições
---------------------------------------------------------------------------

function BaseService.root(player)
	local char = player and player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

function BaseService.position(player)
	local r = BaseService.root(player)
	return r and r.Position
end

function BaseService.baseIndex(player)
	return baseOf[player]
end

function BaseService.owner(index)
	return owners[index]
end

function BaseService.isShielded(index, now)
	return (shieldUntil[index] or 0) > (now or PlayerDataService.now())
end

function BaseService.shieldUntil(index)
	return shieldUntil[index] or 0
end

function BaseService.inOwnBase(player)
	local pos = BaseService.position(player)
	local idx = baseOf[player]
	return pos ~= nil and idx ~= nil and MapConfig.baseAt(pos.X, pos.Z) == idx
end

local function teleportToBase(player)
	local idx = baseOf[player]
	local r = BaseService.root(player)
	if idx and r then
		r.CFrame = CFrame.new(MapService.bases[idx].spawn)
	end
end

---------------------------------------------------------------------------
-- criaturas nos pedestais
---------------------------------------------------------------------------

local function labelText(profile, c, now)
	local s = GameConfig.SpeciesById[c.s]
	local m = GameConfig.Mutations[c.m]
	local rarity = GameConfig.Rarities[s.rarity]
	local mut = c.m ~= "normal" and ("<font color='" .. rgbHex(m.color) .. "'>" .. m.name .. "</font> ") or ""
	local pending = math.floor(Income.pending(profile, c, now))
	return mut .. "<font color='" .. rgbHex(rarity.color) .. "'>" .. s.name .. "</font>\n"
		.. "<font color='#7CFF8A'>+$" .. Format.short(Income.rate(profile, c)) .. "/s</font>  "
		.. "<font color='#FFD84A'>$" .. Format.short(pending) .. "</font>"
end

local function padCFrame(index, pad, speciesId)
	local x, z = MapConfig.padPosition(index, pad)
	local h = CreatureModel.size(speciesId)
	return CFrame.new(x, 1.8 + h / 2, z)
end

local function buildCreature(player, index, c)
	local model = CreatureModel.build(c.s, c.m, { anchored = true })
	model.Name = c.uid
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Uid", c.uid)
	model:SetAttribute("BaseIndex", index)
	model:PivotTo(padCFrame(index, c.pad, c.s))
	local body = model.PrimaryPart
	local label = MapService.billboard(body, "", UDim2.fromOffset(200, 54), CreatureModel.size(c.s) / 2 + 2)
	MapService.prompt(body, "Roubar", GameConfig.SpeciesById[c.s].name, {
		hold = GameConfig.Steal.HoldSeconds,
		distance = GameConfig.Steal.PromptDistance,
		attributes = { Steal = true, OwnerUserId = player.UserId, Uid = c.uid },
	})
	model.Parent = MapService.creatureFolder
	return { model = model, label = label, pad = c.pad, key = c.s .. c.m }
end

function BaseService.render(player)
	local index = baseOf[player]
	local profile = PlayerDataService.getProfile(player)
	if not index or not profile then
		return
	end
	local list = rendered[player]
	if not list then
		list = {}
		rendered[player] = list
	end
	-- remove as que saíram
	for uid, r in pairs(list) do
		local c = profile.creatures[uid]
		if not c or r.key ~= c.s .. c.m then
			r.model:Destroy()
			list[uid] = nil
		end
	end
	-- adiciona/move
	for uid, c in pairs(profile.creatures) do
		local r = list[uid]
		if not r then
			list[uid] = buildCreature(player, index, c)
		elseif r.pad ~= c.pad then
			r.model:PivotTo(padCFrame(index, c.pad, c.s))
			r.pad = c.pad
		end
		local m = list[uid].model
		if hidden[uid] then
			m.Parent = nil
		else
			m.Parent = MapService.creatureFolder
		end
	end
	-- pedestais disponíveis
	local slots = ProfileSchema.slots(profile)
	for i, pad in ipairs(MapService.bases[index].pads) do
		pad.Transparency = i <= slots and 0 or 0.75
		pad.Color = i <= slots and MapService.bases[index].color:Lerp(Color3.fromRGB(40, 40, 55), 0.6) or Color3.fromRGB(45, 48, 62)
	end
	BaseService.updateLabels(player)
end

function BaseService.updateLabels(player)
	local profile = PlayerDataService.getProfile(player)
	local list = rendered[player]
	if not profile or not list then
		return
	end
	local now = PlayerDataService.now()
	for uid, r in pairs(list) do
		local c = profile.creatures[uid]
		if c then
			r.label.Text = labelText(profile, c, now)
		end
	end
end

-- esconde/mostra a criatura do pedestal enquanto alguém a carrega
function BaseService.setHidden(ownerPlayer, uid, isHidden)
	hidden[uid] = isHidden or nil
	local list = rendered[ownerPlayer]
	local r = list and list[uid]
	if r then
		if isHidden then
			r.model.Parent = nil
		else
			r.model.Parent = MapService.creatureFolder
		end
	end
end

local function clearBase(player)
	for _, r in pairs(rendered[player] or {}) do
		r.model:Destroy()
	end
	rendered[player] = nil
	local idx = baseOf[player]
	if idx then
		owners[idx] = nil
		shieldUntil[idx] = nil
		local b = MapService.bases[idx]
		b.sign.Text = "Base livre"
		for _, l in ipairs(b.laser) do
			l.Transparency = 1
		end
		for _, pad in ipairs(b.pads) do
			pad.Transparency = 0.6
		end
	end
	baseOf[player] = nil
end

local function assign(player)
	for i = 1, #MapConfig.Bases do
		if not owners[i] then
			owners[i] = player
			baseOf[player] = i
			player:SetAttribute("BaseIndex", i)
			local b = MapService.bases[i]
			b.sign.Text = "Base de " .. player.DisplayName
			b.collectPrompt:SetAttribute("OwnerUserId", player.UserId)
			b.shieldPrompt:SetAttribute("OwnerUserId", player.UserId)
			shieldUntil[i] = PlayerDataService.now() + GameConfig.Base.NewcomerShield
			return i
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- ações
---------------------------------------------------------------------------

function BaseService.collect(player)
	if not BaseService.inOwnBase(player) then
		return Remotes.fail("not_in_base", "Vá até a sua base para coletar.")
	end
	return PlayerDataService.run(player, function(profile, ctx)
		return ProfileOps.collectAll(profile, ctx)
	end)
end

function BaseService.activateShield(player)
	local idx = baseOf[player]
	if not idx or not BaseService.inOwnBase(player) then
		return Remotes.fail("not_in_base", "Vá até a sua base para travar.")
	end
	local now = PlayerDataService.now()
	if BaseService.isShielded(idx, now) then
		return Remotes.fail("shield_active", "O escudo já está ligado.")
	end
	local res = PlayerDataService.run(player, function(profile, ctx)
		ProfileOps.recordShield(profile, ctx.now)
		return true, { seconds = ProfileOps.shieldSeconds(profile) }
	end)
	if res.ok then
		shieldUntil[idx] = now + res.data.seconds
		if BaseService.shieldHook then
			BaseService.shieldHook(player, idx) -- ladrões ainda dentro da base devolvem a criatura
		end
		PlayerDataService.push(player)
	end
	return res
end

-- empurra para fora quem não é dono e está dentro de uma base com escudo
local function enforceShields(now)
	for idx, owner in pairs(owners) do
		local active = BaseService.isShielded(idx, now)
		local b = MapService.bases[idx]
		for _, l in ipairs(b.laser) do
			l.Transparency = active and 0.15 or 1
		end
		local left = math.max(0, math.ceil((shieldUntil[idx] or 0) - now))
		b.shieldLabel.Text = active and ("🛡️ TRAVADA " .. left .. "s") or "🛡️ TRAVAR BASE"
		if active then
			local base = MapConfig.Bases[idx]
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= owner then
					local r = BaseService.root(p)
					if r and MapConfig.baseAt(r.Position.X, r.Position.Z) == idx then
						local outZ = base.z + base.facing * (MapConfig.BaseSize / 2 + 8)
						r.CFrame = CFrame.new(base.x, 4, outZ)
						BaseService.notify(p, "info", "🛡️ Essa base está com o escudo ligado.")
					end
				end
			end
		end
	end
end

local function updateSpeeds(now)
	for player, _ in pairs(baseOf) do
		local profile = PlayerDataService.getProfile(player)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if profile and hum then
			local carrying = BaseService.carryingProvider and BaseService.carryingProvider(player) ~= nil
			hum.WalkSpeed = ProfileOps.walkSpeed(profile, now, carrying)
		end
	end
end

---------------------------------------------------------------------------
-- ciclo
---------------------------------------------------------------------------

function BaseService.init()
	PlayerDataService.setViewExtraProvider(function(player)
		local idx = baseOf[player]
		return {
			baseIndex = idx,
			shieldUntil = idx and shieldUntil[idx] or 0,
			carrying = BaseService.carryingProvider and BaseService.carryingProvider(player) or nil,
		}
	end)
	PlayerDataService.onLoaded(function(player)
		local idx = assign(player)
		if not idx then
			player:Kick("Servidor cheio (6 bases ocupadas). Entre em outro servidor.")
			return
		end
		BaseService.render(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.3)
			teleportToBase(player)
		end)
		teleportToBase(player)
		BaseService.notify(player, "good", "🏠 Esta é a sua base! Proteção de " .. GameConfig.Base.NewcomerShield .. "s ativa.")
	end)
	PlayerDataService.onChanged(function(player)
		BaseService.render(player)
	end)
	Players.PlayerRemoving:Connect(clearBase)

	BaseService.promptHandlers.Action = function(prompt, player)
		local idx = prompt:GetAttribute("BaseIndex")
		if idx ~= baseOf[player] then
			return
		end
		local res
		if prompt:GetAttribute("Action") == "collect" then
			res = BaseService.collect(player)
			if res.ok then
				BaseService.notify(player, "good", "💰 +$" .. Format.short(res.data.coins))
			end
		elseif prompt:GetAttribute("Action") == "shield" then
			res = BaseService.activateShield(player)
			if res.ok then
				BaseService.notify(player, "good", "🛡️ Base travada por " .. math.floor(res.data.seconds) .. "s!")
			end
		end
		if res and not res.ok then
			BaseService.notify(player, "error", res.message)
		end
	end
end

function BaseService.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		for attr, fn in pairs(BaseService.promptHandlers) do
			if prompt:GetAttribute(attr) ~= nil then
				fn(prompt, player)
				return
			end
		end
	end)
	task.spawn(function()
		local acc = 0
		while true do
			task.wait(0.25)
			local now = PlayerDataService.now()
			enforceShields(now)
			acc = acc + 0.25
			if acc >= 1 then
				acc = 0
				updateSpeeds(now)
				for player in pairs(baseOf) do
					BaseService.updateLabels(player)
				end
			end
		end
	end)
end

BaseService._owners = owners
BaseService._baseOf = baseOf
BaseService._rendered = rendered

return BaseService
