-- CollectionService (do jogo; não confundir com o serviço CollectionService do Roblox):
-- recompensas por completar coleções do Índice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ProfileOps = require(Shared.Logic.ProfileOps)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local Validate = require(script.Parent.Parent.Core.Validate)
local PlayerDataService = require(script.Parent.PlayerDataService)

local GameCollectionService = {}

function GameCollectionService.init() end

function GameCollectionService.start()
	Remotes.on("ClaimReward", "claimCollection", "Progression", function(player, payload)
		if not Validate.id(payload.collectionId, 24) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.claimCollection(profile, ctx, payload.collectionId)
		end, { important = true })
	end)
end

return GameCollectionService
