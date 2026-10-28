-- LeaderboardStats: valores enviados aos rankings, derivados de uma única fonte (o perfil).
-- Patrimônio usa Wealth (cada skin contada uma vez; pendente do banco contado uma vez —
-- resgatar só move o valor para o saldo, então o ranking não muda nem duplica).

local Shared = script.Parent.Parent
local Wealth = require(Shared.Logic.Wealth)
local ProfileOps = require(Shared.Logic.ProfileOps)
local BankMath = require(Shared.Logic.BankMath)

local LeaderboardStats = {}

LeaderboardStats.Boards = {
	{ id = "netWorth", displayName = "Patrimônio líquido" },
	{ id = "level", displayName = "Nível" },
	{ id = "unique", displayName = "Skins únicas" },
	{ id = "collections", displayName = "Coleções concluídas" },
	{ id = "achievements", displayName = "Conquistas" },
	{ id = "bankIncome", displayName = "Renda do banco" },
}

function LeaderboardStats.compute(profile)
	local achievements = 0
	for _ in pairs(profile.achievements) do
		achievements = achievements + 1
	end
	return {
		netWorth = math.floor(Wealth.netWorth(profile)),
		-- nível considera renascimentos para ordenar (renascimento * 1000 + nível)
		level = profile.rebirths * 1000 + profile.level,
		unique = ProfileOps.statValue(profile, "uniqueDiscovered"),
		collections = ProfileOps.statValue(profile, "collectionsCompleted"),
		achievements = achievements,
		-- renda em centésimos de crédito/s (OrderedDataStore guarda inteiros)
		bankIncome = math.floor(BankMath.totalRate(profile) * 100 + 0.5),
	}
end

return LeaderboardStats
