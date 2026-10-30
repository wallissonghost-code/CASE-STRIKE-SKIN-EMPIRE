-- Raridades do jogo. `rank` ordena da mais comum (1) para a mais rara (6).
-- confirmSale: a venda pede confirmação. effect: efeito especial na abertura.

local RarityConfig = {}

RarityConfig.Order = { "common", "uncommon", "rare", "epic", "legendary", "secret" }

RarityConfig.Rarities = {
	common = { name = "Comum", rank = 1, color = Color3.fromRGB(170, 176, 186), xp = 30 },
	uncommon = { name = "Incomum", rank = 2, color = Color3.fromRGB(88, 204, 98), xp = 50 },
	rare = { name = "Raro", rank = 3, color = Color3.fromRGB(70, 150, 255), xp = 90, confirmSale = true },
	epic = { name = "Épico", rank = 4, color = Color3.fromRGB(176, 92, 255), xp = 150, confirmSale = true },
	legendary = { name = "Lendário", rank = 5, color = Color3.fromRGB(255, 196, 40), xp = 300, confirmSale = true, effect = "legendary", announce = true },
	secret = { name = "Secreto", rank = 6, color = Color3.fromRGB(255, 52, 64), xp = 600, confirmSale = true, effect = "secret", announce = true },
}

function RarityConfig.get(id)
	return RarityConfig.Rarities[id]
end

function RarityConfig.rank(id)
	local r = RarityConfig.Rarities[id]
	return r and r.rank or 0
end

return RarityConfig
