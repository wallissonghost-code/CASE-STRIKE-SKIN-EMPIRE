-- ConveyorService: a esteira da fábrica. Criaturas sorteadas pelo SERVIDOR atravessam a praça;
-- qualquer jogador pode comprar a que passar (quem chegar primeiro leva).
-- Preço = preço da espécie × mutação. Eventos podem acelerar a esteira e dar sorte extra.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local MapConfig = require(Shared.Config.MapConfig)
local EventConfig = require(Shared.Config.EventConfig)
local ProfileOps = require(Shared.Logic.ProfileOps)
local Format = require(Shared.Util.Format)
local CreatureModel = require(Shared.Visual.CreatureModel)

local PlayerDataService = require(script.Parent.PlayerDataService)
local MapService = require(script.Parent.MapService)
local BaseService = require(script.Parent.BaseService)

local ConveyorService = {}

local items = {} -- [id] = { model, offer, x, label }
local nextId = 0
local rng = Random.new()
local BUY_DISTANCE = 16

local function rgbHex(t)
	return string.format("#%02X%02X%02X", t[1], t[2], t[3])
end

local function isRare(offer)
	local s = GameConfig.SpeciesById[offer.speciesId]
	return GameConfig.tier(s.rarity) >= 5 or GameConfig.Mutations[offer.mutationId].tier >= 3
end

local function describe(offer)
	local s = GameConfig.SpeciesById[offer.speciesId]
	local m = GameConfig.Mutations[offer.mutationId]
	return (offer.mutationId ~= "normal" and (m.name .. " ") or "") .. s.name
end
ConveyorService.describe = describe

function ConveyorService.spawn(now)
	local count = 0
	for _ in pairs(items) do
		count = count + 1
	end
	if count >= GameConfig.Conveyor.MaxOnBelt then
		return nil
	end
	local offer = ProfileOps.rollConveyor(now, rng:NextNumber(), rng:NextNumber())
	nextId = nextId + 1
	local id = "b" .. nextId
	local c = MapConfig.Conveyor
	local model = CreatureModel.build(offer.speciesId, offer.mutationId, { anchored = true })
	model.Name = id
	model:SetAttribute("ConveyorId", id)
	local h = CreatureModel.size(offer.speciesId)
	model:PivotTo(CFrame.new(c.startX, c.y + h / 2, c.z))
	local s = GameConfig.SpeciesById[offer.speciesId]
	local m = GameConfig.Mutations[offer.mutationId]
	local rarity = GameConfig.Rarities[s.rarity]
	local text = (offer.mutationId ~= "normal" and ("<font color='" .. rgbHex(m.color) .. "'>" .. m.name .. "</font> ") or "")
		.. "<font color='" .. rgbHex(rarity.color) .. "'>" .. s.name .. "</font>\n"
		.. "<font color='#FFD84A'>$" .. Format.short(offer.price) .. "</font>  <font color='#7CFF8A'>+$" .. Format.short(s.income * m.mult) .. "/s</font>"
	local label = MapService.billboard(model.PrimaryPart, text, UDim2.fromOffset(210, 56), h / 2 + 2.5)
	MapService.prompt(model.PrimaryPart, "Comprar", "$" .. Format.short(offer.price), { distance = 12, attributes = { ConveyorId = id } })
	model.Parent = MapService.beltFolder
	items[id] = { model = model, offer = offer, x = c.startX, label = label, h = h }
	if isRare(offer) then
		BaseService.notifyAll("rare", "✨ Na esteira: " .. describe(offer) .. " (" .. rarity.displayName .. ")!")
	end
	return id
end

function ConveyorService.buy(player, id)
	local item = items[id]
	if not item then
		return { ok = false, error = "offer_gone", message = ProfileOps.Messages.offer_gone }
	end
	local pos = BaseService.position(player)
	if not pos then
		return { ok = false, error = "too_far", message = "Chegue mais perto da esteira." }
	end
	local dx = pos.X - item.x
	local dz = pos.Z - MapConfig.Conveyor.z
	if dx * dx + dz * dz > BUY_DISTANCE * BUY_DISTANCE then
		return { ok = false, error = "too_far", message = "Chegue mais perto da esteira." }
	end
	local offer = item.offer
	local res = PlayerDataService.run(player, function(profile, ctx)
		return ProfileOps.buyFromConveyor(profile, ctx, offer)
	end, { important = true })
	if res.ok then
		items[id] = nil
		item.model:Destroy()
		BaseService.notify(player, "good", "🛒 " .. describe(offer) .. " foi para a sua base!")
		if isRare(offer) then
			BaseService.notifyAll("rare", "🛒 " .. player.DisplayName .. " comprou " .. describe(offer) .. "!")
		end
	end
	return res
end

function ConveyorService.step(dt)
	local c = MapConfig.Conveyor
	local speed = (c.endX - c.startX) / GameConfig.Conveyor.TravelSeconds
	for id, item in pairs(items) do
		item.x = item.x + speed * dt
		if item.x >= c.endX then
			items[id] = nil
			item.model:Destroy()
		else
			item.model:PivotTo(CFrame.new(item.x, c.y + item.h / 2, c.z))
		end
	end
end

function ConveyorService.init()
	BaseService.promptHandlers.ConveyorId = function(prompt, player)
		local res = ConveyorService.buy(player, prompt:GetAttribute("ConveyorId"))
		if not res.ok then
			BaseService.notify(player, "error", res.message)
		end
	end
end

function ConveyorService.start()
	task.spawn(function()
		local sinceSpawn = 999
		while true do
			local dt = task.wait() -- um quadro: movimento suave
			local now = PlayerDataService.now()
			ConveyorService.step(dt)
			local ev = EventConfig.at(now)
			local interval = GameConfig.Conveyor.SpawnInterval
			if ev and ev.kind == "conveyor" then
				interval = interval * ev.intervalMult
			end
			sinceSpawn = sinceSpawn + dt
			if sinceSpawn >= interval then
				sinceSpawn = 0
				ConveyorService.spawn(now)
			end
		end
	end)
end

ConveyorService._items = items

return ConveyorService
