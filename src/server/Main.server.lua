-- Ponto de entrada do servidor: inicializa remotes e serviços em ordem.
-- Nenhum serviço de combate é carregado (PvP, monstros e chefes estão bloqueados).

local Services = script.Parent.Services
local Remotes = require(script.Parent.Core.Remotes)

Remotes.init()

local order = {
	"PlayerDataService",
	"LobbyService",
	"CaseService",
	"InventoryService",
	"EconomyService",
	"BankService",
	"UpgradeService",
	"CollectionService",
	"MissionService",
	"RewardService",
	"ProgressionService",
	"LeaderboardService",
}

local loaded = {}
for _, name in ipairs(order) do
	loaded[name] = require(Services:WaitForChild(name))
end
for _, name in ipairs(order) do
	loaded[name].init()
end
-- PlayerDataService começa por último: assim todos os ouvintes (onLoaded/onChanged)
-- já estão registrados quando o primeiro perfil carregar.
for _, name in ipairs(order) do
	if name ~= "PlayerDataService" then
		loaded[name].start()
	end
end
loaded.PlayerDataService.start()

print("[CASE STRIKE] servidor pronto")
