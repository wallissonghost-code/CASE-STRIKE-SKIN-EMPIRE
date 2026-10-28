-- Wealth: patrimônio líquido e valor dos equipamentos.
-- Patrimônio = saldo + valor de TODAS as skins possuídas (inventário + banco), cada instância uma única vez,
-- + créditos pendentes de resgate no banco (parte inteira). Resgatar apenas move pendente -> saldo,
-- então o patrimônio não muda (e a renda nunca é contada duas vezes).
-- Valor dos equipamentos é apenas um indicador (as equipadas já estão contadas no patrimônio).

local Shared = script.Parent.Parent
local SkinDefinitions = require(Shared.Config.SkinDefinitions)

local Wealth = {}

function Wealth.itemValue(item)
	local def = SkinDefinitions.ById[item.defId]
	return def and def.value or 0
end

function Wealth.compute(profile)
	local inventoryValue, bankValue, equipValue = 0, 0, 0
	local count = 0
	for _, item in pairs(profile.inventory) do
		local v = Wealth.itemValue(item)
		count = count + 1
		if item.location == "bank" then
			bankValue = bankValue + v
		else
			inventoryValue = inventoryValue + v
			if item.equipped then
				equipValue = equipValue + v
			end
		end
	end
	local pending = math.floor((profile.bank and profile.bank.pending) or 0)
	return {
		credits = profile.credits,
		pending = pending,
		inventoryValue = inventoryValue,
		bankValue = bankValue,
		equipValue = equipValue,
		netWorth = profile.credits + inventoryValue + bankValue + pending,
		itemCount = count,
	}
end

function Wealth.netWorth(profile)
	return Wealth.compute(profile).netWorth
end

return Wealth
