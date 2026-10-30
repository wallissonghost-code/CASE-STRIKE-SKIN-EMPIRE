-- Economia, XP e níveis. Todos os valores são lidos pelo servidor; o cliente só exibe.

local EconomyConfig = {}

EconomyConfig.CurrencyName = "Coins"
EconomyConfig.StartingCoins = 250
EconomyConfig.MaxCoins = 1000000000

-- Níveis de colecionador: XP necessário para sair do nível L = Base + PerLevel * (L - 1)
EconomyConfig.Levels = {
	Base = 50,
	PerLevel = 25,
	MaxLevel = 60,
}

-- Moedas pagas ao alcançar um novo nível (uma única vez por nível)
function EconomyConfig.levelReward(level)
	return 25 + 15 * level
end

-- XP por uso de máquina: pequeno e com limite diário (evita XP infinito por repetição)
EconomyConfig.OpenXp = 5
EconomyConfig.OpenXpDailyCap = 150

-- Multiplicador das recompensas em moedas de missões e presentes conforme o nível
-- (para continuarem úteis quando as máquinas ficam caras). O bônus de melhoria soma por cima.
function EconomyConfig.levelScale(level)
	return 1 + 0.08 * (math.max(1, level) - 1)
end

-- Presente diário gratuito (sequência de 7 dias; perder um dia recomeça a sequência)
EconomyConfig.DailyGift = {
	coins = { 60, 80, 100, 140, 180, 240, 400 },
	xp = 25,
}

-- Moedas perdidas pelo parque: atividade gratuita para quem ficou sem saldo
EconomyConfig.Pickups = {
	spots = 8, -- quantas moedas existem ao mesmo tempo no mapa
	respawn = 20, -- segundos até uma moeda reaparecer
	hourlyLimit = 20, -- máximo de moedas coletadas por jogador por hora
	baseCoins = 6,
	perLevel = 2,
	radius = 9, -- distância máxima para validar a coleta
}

function EconomyConfig.pickupValue(level)
	return EconomyConfig.Pickups.baseCoins + EconomyConfig.Pickups.perLevel * math.max(1, level)
end

-- Venda: as raridades com confirmSale (RarityConfig) pedem confirmação.
-- "Vender repetidos" vende as cópias extras destas raridades, mantendo 1 de cada.
EconomyConfig.DuplicateSellRarities = { common = true, uncommon = true }

-- Salvamento e proteção
EconomyConfig.AutosaveInterval = 60
EconomyConfig.SessionLockTimeout = 300
EconomyConfig.OpenCooldown = 0.6

-- Ranking global (OrderedDataStore): escrita e leitura periódicas com cache
EconomyConfig.LeaderboardRefresh = 300
EconomyConfig.LeaderboardWriteInterval = 300
EconomyConfig.LeaderboardSize = 10

return EconomyConfig
