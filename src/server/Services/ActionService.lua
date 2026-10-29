-- ActionService: trata os pedidos dos remotes. O cliente só manda ids e escolhas;
-- preços, sorteios e quantidades vêm sempre do servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local ProfileOps = require(Shared.Logic.ProfileOps)
local Income = require(Shared.Logic.Income)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local Validate = require(script.Parent.Parent.Core.Validate)
local PlayerDataService = require(script.Parent.PlayerDataService)
local BaseService = require(script.Parent.BaseService)
local EventService = require(script.Parent.EventService)

local ActionService = {}

local function bad()
	return Remotes.fail("invalid_request", "Pedido inválido.")
end

local function op(player, fn, important)
	return PlayerDataService.run(player, fn, { important = important })
end

function ActionService.init()
	-- ovos e poções
	Remotes.on("EggAction", "hatch", "Hatch", function(player, p)
		if not GameConfig.Eggs[p.eggId] then
			return bad()
		end
		local res = op(player, function(profile, ctx)
			return ProfileOps.hatchEgg(profile, ctx, p.eggId)
		end, true)
		if res.ok then
			local c = res.data.creature
			local s = GameConfig.SpeciesById[c.s]
			if GameConfig.tier(s.rarity) >= 5 or GameConfig.Mutations[c.m].tier >= 3 then
				local m = GameConfig.Mutations[c.m]
				BaseService.notifyAll("rare", "🥚 " .. player.DisplayName .. " chocou " .. (c.m ~= "normal" and (m.name .. " ") or "") .. s.name .. "!")
			end
			res.data = { speciesId = c.s, mutationId = c.m, uid = c.uid, isNew = res.data.isNew, cost = res.data.cost }
		end
		return res
	end)
	Remotes.on("EggAction", "buyPotion", "Base", function(player, p)
		if not GameConfig.Potions[p.potionId] then
			return bad()
		end
		return op(player, function(profile, ctx)
			return ProfileOps.buyPotion(profile, ctx, p.potionId)
		end)
	end)
	Remotes.on("EggAction", "usePotion", "Base", function(player, p)
		if not GameConfig.Potions[p.potionId] then
			return bad()
		end
		return op(player, function(profile, ctx)
			return ProfileOps.activatePotion(profile, ctx, p.potionId)
		end, true)
	end)

	-- base
	Remotes.on("BaseAction", "collect", "Base", function(player)
		return BaseService.collect(player)
	end)
	Remotes.on("BaseAction", "shield", "Base", function(player)
		return BaseService.activateShield(player)
	end)
	Remotes.on("BaseAction", "sell", "Base", function(player, p)
		if not Validate.id(p.uid, 24) then
			return bad()
		end
		return op(player, function(profile, ctx)
			return ProfileOps.sell(profile, ctx, p.uid, p.confirm == true)
		end, true)
	end)
	Remotes.on("BaseAction", "upgrade", "Base", function(player, p)
		if not GameConfig.Upgrades[p.upgradeId] then
			return bad()
		end
		return op(player, function(profile, ctx)
			return ProfileOps.buyUpgrade(profile, ctx, p.upgradeId)
		end, true)
	end)
	Remotes.on("BaseAction", "move", "Base", function(player, p)
		if not Validate.id(p.uid, 24) or not Validate.int(p.pad, 1, GameConfig.Base.MaxSlotsShown) then
			return bad()
		end
		return op(player, function(profile, ctx)
			return ProfileOps.movePad(profile, ctx, p.uid, p.pad)
		end)
	end)

	-- recompensas e renascimento
	Remotes.on("ClaimAction", "mission", "Claim", function(player, p)
		if not Validate.id(p.missionId, 32) then
			return bad()
		end
		return op(player, function(profile, ctx)
			return ProfileOps.claimMission(profile, ctx, p.missionId)
		end, true)
	end)
	Remotes.on("ClaimAction", "gift", "Claim", function(player)
		return op(player, function(profile, ctx)
			return ProfileOps.claimGift(profile, ctx)
		end, true)
	end)
	Remotes.on("ClaimAction", "milestone", "Claim", function(player, p)
		if not Validate.id(p.milestoneId, 16) then
			return bad()
		end
		return op(player, function(profile, ctx)
			return ProfileOps.claimMilestone(profile, ctx, p.milestoneId)
		end, true)
	end)
	Remotes.on("ClaimAction", "rebirth", "Claim", function(player, p)
		if type(p.phrase) ~= "string" or #p.phrase > 20 then
			return bad()
		end
		local res = op(player, function(profile, ctx)
			return ProfileOps.rebirth(profile, ctx, p.phrase)
		end, true)
		if res.ok then
			BaseService.notifyAll("rare", "♻️ " .. player.DisplayName .. " renasceu! (" .. res.data.rebirths .. "º)")
		end
		return res
	end)

	-- ajustes
	Remotes.on("SettingsAction", "set", "Settings", function(player, p)
		return op(player, function(profile)
			return ProfileOps.setSetting(profile, p.key, p.value)
		end)
	end)
	-- só no Studio: força um evento para testar (nunca em servidores publicados)
	Remotes.on("SettingsAction", "testEvent", "Settings", function(player, p)
		if not RunService:IsStudio() then
			return Remotes.fail("forbidden", "Disponível só no Studio.")
		end
		if not Validate.id(p.eventId, 32) then
			return bad()
		end
		local ev = EventService.force(p.eventId, 120)
		if not ev then
			return bad()
		end
		return { ok = true, data = { id = ev.id } }
	end)

	-- ranking do servidor
	Remotes.on("RankingRequest", "get", "Ranking", function()
		local rows = {}
		for _, pl in ipairs(Players:GetPlayers()) do
			local profile = PlayerDataService.getProfile(pl)
			if profile then
				table.insert(rows, {
					name = pl.DisplayName,
					coins = profile.coins,
					rate = Income.totalRate(profile),
					netWorth = Income.netWorth(profile),
					stolen = profile.stats.stolen,
					defended = profile.stats.defended,
					rebirths = profile.rebirths,
				})
			end
		end
		table.sort(rows, function(a, b)
			return a.netWorth > b.netWorth
		end)
		return { ok = true, data = rows }
	end)
end

function ActionService.start() end

return ActionService
