-- Ponto de entrada do servidor do MUTANT FACTORY: cria os remotes e inicia os serviços em ordem.

local Services = script.Parent.Services
local Remotes = require(script.Parent.Core.Remotes)

Remotes.init()

local order = {
	"PlayerDataService",
	"MapService",
	"BaseService",
	"ConveyorService",
	"StealService",
	"EventService",
	"ActionService",
}

local loaded = {}
for _, name in ipairs(order) do
	loaded[name] = require(Services:WaitForChild(name))
end
for _, name in ipairs(order) do
	loaded[name].init()
end
-- PlayerDataService começa por último: todos os ouvintes já estão registrados quando o primeiro perfil carregar
for _, name in ipairs(order) do
	if name ~= "PlayerDataService" then
		loaded[name].start()
	end
end
loaded.PlayerDataService.start()

print("[MUTANT FACTORY] servidor pronto")
