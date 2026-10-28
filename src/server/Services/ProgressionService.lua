-- ProgressionService: renascimento (com confirmação inequívoca) e títulos.
-- Níveis e XP são concedidos pela lógica de cada operação (Logic/Progression).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ProfileOps = require(Shared.Logic.ProfileOps)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local Validate = require(script.Parent.Parent.Core.Validate)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ProgressionService = {}

function ProgressionService.init() end

function ProgressionService.start()
	Remotes.on("ProgressionAction", "rebirth", "Progression", function(player, payload)
		if type(payload.confirmPhrase) ~= "string" or #payload.confirmPhrase > 32 then
			return Remotes.fail("confirmation_required", ProfileOps.Messages.confirmation_required)
		end
		local response = PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.rebirth(profile, ctx, payload.confirmPhrase)
		end, { important = true })
		return response
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
