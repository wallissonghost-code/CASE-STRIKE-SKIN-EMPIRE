-- AttributeConfig: atributos do colecionador, comprados com créditos do jogo.
-- Cada atributo tem nível, limite máximo, custo progressivo e benefício atual/seguinte.
-- "Eficiência do banco" e "Capacidade de banco" são as MESMAS melhorias do banco
-- (linkedBankUpgrade): comprar em qualquer um dos painéis altera o mesmo nível.

local AttributeConfig = {}

local function pct(x)
	local s = string.format("%.0f", x * 100)
	return s .. "%"
end

AttributeConfig.Order = { "luck", "bankEfficiency", "bankCapacity", "xpBonus", "openSpeed", "multiOpen" }

AttributeConfig.Attributes = {
	luck = {
		id = "luck",
		displayName = "Sorte",
		description = "Aumenta o peso das skins Raras ou melhores (chances finais sempre exibidas).",
		maxLevel = 10,
		baseCost = 2000,
		growth = 2.1,
		perLevel = 0.01,
		requiredLevel = function(level)
			return 2 + level * 4
		end,
		benefit = function(level)
			return "+" .. pct(level * 0.01) .. " de sorte"
		end,
	},
	bankEfficiency = {
		id = "bankEfficiency",
		displayName = "Eficiência do banco",
		description = "Mais créditos por segundo para cada skin depositada.",
		linkedBankUpgrade = "efficiency",
		benefit = function(level)
			return "+" .. pct(level * 0.04) .. " de renda"
		end,
	},
	bankCapacity = {
		id = "bankCapacity",
		displayName = "Capacidade de banco",
		description = "Mais vagas para depositar skins.",
		linkedBankUpgrade = "slots",
		benefit = function(level)
			return "+" .. level .. " vaga(s)"
		end,
	},
	xpBonus = {
		id = "xpBonus",
		displayName = "Bônus de XP",
		description = "Mais experiência em todas as fontes.",
		maxLevel = 10,
		baseCost = 1500,
		growth = 2.0,
		perLevel = 0.05,
		requiredLevel = function(level)
			return 2 + level * 3
		end,
		benefit = function(level)
			return "+" .. pct(level * 0.05) .. " de XP"
		end,
	},
	openSpeed = {
		id = "openSpeed",
		displayName = "Velocidade de abertura",
		description = "Roleta mais curta e menor intervalo entre aberturas.",
		maxLevel = 5,
		baseCost = 800,
		growth = 2.5,
		perLevel = 0.08,
		requiredLevel = function(level)
			return 1 + level * 3
		end,
		benefit = function(level)
			return "-" .. pct(level * 0.08) .. " no tempo de abertura"
		end,
	},
	multiOpen = {
		id = "multiOpen",
		displayName = "Limite de abertura múltipla",
		description = "Libera a abertura de 25 caixas de uma vez.",
		maxLevel = 1,
		baseCost = 15000,
		growth = 1,
		requiredLevel = function()
			return 15
		end,
		benefit = function(level)
			return level >= 1 and "até ×25 por abertura" or "até ×10 por abertura"
		end,
	},
}

function AttributeConfig.cost(attr, currentLevel)
	return math.floor(attr.baseCost * (attr.growth ^ currentLevel) + 0.5)
end

-- maior quantidade permitida por abertura
function AttributeConfig.maxQuantity(multiOpenLevel)
	if (multiOpenLevel or 0) >= 1 then
		return 25
	end
	return 10
end

-- fator multiplicativo de duração/intervalo (1 = normal)
function AttributeConfig.speedFactor(openSpeedLevel)
	return 1 - (openSpeedLevel or 0) * AttributeConfig.Attributes.openSpeed.perLevel
end

return AttributeConfig
