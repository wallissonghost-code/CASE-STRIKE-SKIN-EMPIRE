-- EconomyService: venda de skins ao sistema por créditos (atômica e protegida contra repetição).
-- Não existe mercado externo, saque ou conversão em Robux/dinheiro real.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ProfileOps = require(Shared.Logic.ProfileOps)
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local RarityConfig = require(Shared.Config.RarityConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local Validate = require(script.Parent.Parent.Core.Validate)
local PlayerDataService = require(script.Parent.PlayerDataService)

local EconomyService = {}

function EconomyService.init() end

function EconomyService.start()
	-- vender instâncias específicas
	Remotes.on("InventoryAction", "sell", "Inventory", function(player, payload)
		if not Validate.idList(payload.uids, 200) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.sellItems(profile, ctx, payload.uids, payload.confirmFavorites == true, payload.confirmValuable == true)
		end, { important = true })
	end)

	-- vender todas as skins até uma raridade (nunca inclui favoritas, equipadas, expostas,
	-- depositadas nem Lendárias/Secretas, que exigem confirmação individual)
	Remotes.on("InventoryAction", "sellBulk", "Inventory", function(player, payload)
		if not Validate.int(payload.maxTier, 1, EconomyConfig.ValuableConfirmTier - 1) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			local uids = {}
			for uid, item in pairs(profile.inventory) do
				local def = SkinDefinitions.ById[item.defId]
				if
					item.location == "inventory"
					and not item.favorite
					and not item.equipped
					and not item.showcase
					and RarityConfig.tier(def.rarity) <= payload.maxTier
				then
					table.insert(uids, uid)
					if #uids >= 200 then
						break
					end
				end
			end
			if #uids == 0 then
				return false, "invalid_item"
			end
			return ProfileOps.sellItems(profile, ctx, uids, false)
		end, { important = true })
	end)
end

return EconomyService
