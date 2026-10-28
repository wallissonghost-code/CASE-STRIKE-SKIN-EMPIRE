-- BankService: depósitos, retiradas, resgate e melhorias do banco.
-- A renda é calculada por timestamps em BankMath (sem loop por skin); o cliente
-- apenas extrapola o valor pendente para exibição entre as atualizações.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ProfileOps = require(Shared.Logic.ProfileOps)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local Validate = require(script.Parent.Parent.Core.Validate)
local PlayerDataService = require(script.Parent.PlayerDataService)

local BankService = {}

function BankService.init() end

function BankService.start()
	Remotes.on("BankAction", "deposit", "Bank", function(player, payload)
		if not Validate.id(payload.uid, 24) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.deposit(profile, ctx, payload.uid)
		end)
	end)

	Remotes.on("BankAction", "withdraw", "Bank", function(player, payload)
		if not Validate.id(payload.uid, 24) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.withdraw(profile, ctx, payload.uid)
		end)
	end)

	Remotes.on("BankAction", "claim", "Bank", function(player)
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.claimBank(profile, ctx)
		end, { important = true })
	end)

	Remotes.on("BankAction", "upgrade", "Bank", function(player, payload)
		if not Validate.id(payload.upgradeId, 24) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		return PlayerDataService.run(player, function(profile, ctx)
			return ProfileOps.buyBankUpgrade(profile, ctx, payload.upgradeId)
		end, { important = true })
	end)
end

return BankService
