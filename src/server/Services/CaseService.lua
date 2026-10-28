-- CaseService: abertura de caixas (1, 5 ou 10), modo rápido e abertura automática.
-- Fluxo: valida -> desconta -> sorteia no servidor -> entrega ao inventário -> responde ao cliente,
-- que apenas anima a roleta até o prêmio já determinado.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ProfileOps = require(Shared.Logic.ProfileOps)
local AutoOpen = require(Shared.Logic.AutoOpen)
local Probability = require(Shared.Logic.Probability)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local CaseDefinitions = require(Shared.Config.CaseDefinitions)
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local RarityConfig = require(Shared.Config.RarityConfig)
local AttributeConfig = require(Shared.Config.AttributeConfig)
local DropValidator = require(Shared.Logic.DropValidator)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local Validate = require(script.Parent.Parent.Core.Validate)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CaseService = {}

local autoSessions = {} -- [player] = AutoOpen
local lastOpenAt = {} -- [player] = os.clock()

local function autoFor(player)
	local s = autoSessions[player]
	if not s then
		s = AutoOpen.new()
		autoSessions[player] = s
	end
	return s
end

local function announce(player, results)
	-- anuncia drops Lendários/Secretos para todos do servidor
	for _, r in ipairs(results) do
		local def = SkinDefinitions.ById[r.defId]
		if RarityConfig.tier(def.rarity) >= 5 then
			Remotes.event("CaseOpenResult"):FireAllClients({
				kind = "rareDrop",
				playerName = player.DisplayName,
				defId = def.id,
			})
		end
	end
end

local function handleOpen(player, payload)
	local caseId = payload.caseId
	local quantity = payload.quantity
	if not Validate.id(caseId, 24) or not Validate.int(quantity, 1, 25) then
		return Remotes.fail("invalid_request", "Pedido inválido.")
	end
	if not CaseDefinitions.AllowedQuantities[quantity] then
		return Remotes.fail("invalid_quantity", ProfileOps.Messages.invalid_quantity)
	end
	local fast = payload.fast == true
	local isAuto = payload.auto == true

	-- intervalo mínimo entre aberturas (servidor)
	local clock = os.clock()
	local profileNow = PlayerDataService.getProfile(player)
	local speed = AttributeConfig.speedFactor(profileNow and profileNow.attributes.openSpeed or 0)
	local minInterval = (fast and EconomyConfig.Opening.MinIntervalFast or EconomyConfig.Opening.MinIntervalNormal) * speed
	if lastOpenAt[player] and clock - lastOpenAt[player] < minInterval then
		return Remotes.fail("rate_limited", "Aguarde a roleta terminar.")
	end

	local auto = autoFor(player)
	if isAuto then
		local can, why = auto:check(caseId, quantity, clock)
		if not can then
			local messages = {
				auto_inactive = "A abertura automática está desligada.",
				auto_mismatch = "A abertura automática foi iniciada para outra caixa.",
				auto_limit_opens = "Limite da sessão automática atingido. Reative para continuar.",
				auto_limit_time = "Tempo máximo da sessão automática atingido. Reative para continuar.",
				auto_too_fast = "Aguarde a roleta terminar.",
			}
			return Remotes.fail(why, messages[why])
		end
	end

	local response = PlayerDataService.run(player, function(profile, ctx)
		return ProfileOps.openCases(profile, ctx, caseId, quantity, { useFree = payload.useFree == true })
	end, { important = true })

	if response.ok then
		lastOpenAt[player] = clock
		if isAuto then
			auto:record(clock)
			response.data.auto = { opens = auto.opens, maxOpens = EconomyConfig.Opening.AutoMaxOpensPerSession }
		end
		announce(player, response.data.results)
	elseif isAuto then
		auto:stop(response.error) -- saldo insuficiente, inventário cheio etc. encerram o automático
	end
	return response
end

-- Valida todas as tabelas de RNG na inicialização; caixas com problemas ficam indisponíveis.
function CaseService.init()
	local errors, badCases = DropValidator.validate()
	for _, e in ipairs(errors) do
		warn("[CaseService] validação de conteúdo: " .. e)
	end
	for caseId in pairs(badCases) do
		local c = CaseDefinitions.ById[caseId]
		if c then
			c.available = false
		end
	end
end

function CaseService.start()
	Remotes.on("RequestCaseOpen", "open", "CaseOpen", handleOpen)

	Remotes.on("RequestCaseOpen", "startAuto", "CaseOpen", function(player, payload)
		if not Validate.id(payload.caseId, 24) or not Validate.int(payload.quantity, 1, 25) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		if not CaseDefinitions.ById[payload.caseId] or not CaseDefinitions.AllowedQuantities[payload.quantity] then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		autoFor(player):start(payload.caseId, payload.quantity, os.clock())
		return {
			ok = true,
			data = {
				maxOpens = EconomyConfig.Opening.AutoMaxOpensPerSession,
				maxSeconds = EconomyConfig.Opening.AutoMaxSessionSeconds,
			},
		}
	end)

	Remotes.on("RequestCaseOpen", "stopAuto", "Inventory", function(player)
		autoFor(player):stop("user")
		return { ok = true, data = {} }
	end)

	-- probabilidades finais (com a sorte atual) exatamente como o servidor sorteará
	Remotes.on("RequestCaseOpen", "odds", "Inventory", function(player, payload)
		if not Validate.id(payload.caseId, 24) then
			return Remotes.fail("invalid_request", "Pedido inválido.")
		end
		local profile = PlayerDataService.getProfile(player)
		if not profile then
			return Remotes.fail("not_loaded", "Carregando...")
		end
		local entries, luck = ProfileOps.caseOdds(profile, payload.caseId, DateTime.now().UnixTimestamp)
		if not entries then
			return Remotes.fail("invalid_case", ProfileOps.Messages.invalid_case)
		end
		local shown = Probability.displayPercents(entries, 3)
		local list = {}
		for i, e in ipairs(entries) do
			list[i] = { skinId = e.skinId, probability = e.probability, percent = shown[i] }
		end
		return { ok = true, data = { caseId = payload.caseId, luck = luck, odds = list } }
	end)

	Players.PlayerRemoving:Connect(function(player)
		autoSessions[player] = nil
		lastOpenAt[player] = nil
	end)
end

return CaseService
