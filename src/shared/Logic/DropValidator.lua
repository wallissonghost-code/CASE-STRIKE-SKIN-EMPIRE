-- DropValidator: valida as tabelas de RNG e as referências de conteúdo.
-- Executado na inicialização do servidor (caixas inválidas ficam indisponíveis) e nos testes.
-- Verifica: pesos, resultados possíveis, probabilidades totais, itens existentes e requisitos,
-- além de recompensas que citam caixas, títulos ou bônus inexistentes.

local Shared = script.Parent.Parent
local RarityConfig = require(Shared.Config.RarityConfig)
local SkinDefinitions = require(Shared.Config.SkinDefinitions)
local CaseDefinitions = require(Shared.Config.CaseDefinitions)
local ProgressionConfig = require(Shared.Config.ProgressionConfig)
local MissionDefinitions = require(Shared.Config.MissionDefinitions)
local EventDefinitions = require(Shared.Config.EventDefinitions)
local AchievementDefinitions = require(Shared.Config.AchievementDefinitions)
local LuckConfig = require(Shared.Config.LuckConfig)
local PotionConfig = require(Shared.Config.PotionConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local Probability = require(Shared.Logic.Probability)

local DropValidator = {}

-- Retorna (listaDeErros, casosInválidos[id] = true)
function DropValidator.validate()
	local errors = {}
	local badCases = {}
	local function err(caseId, msg)
		table.insert(errors, msg)
		if caseId then
			badCases[caseId] = true
		end
	end

	local seenSkin = {}
	for _, s in ipairs(SkinDefinitions.List) do
		if seenSkin[s.id] then
			err(nil, "skin duplicada: " .. s.id)
		end
		seenSkin[s.id] = true
		if not RarityConfig.Rarities[s.rarity] then
			err(s.caseId, "skin com raridade inexistente: " .. s.id)
		end
		if type(s.value) ~= "number" or s.value < 1 then
			err(s.caseId, "skin com valor inválido: " .. s.id)
		end
		if not SkinDefinitions.Categories[s.category] then
			err(s.caseId, "skin com categoria inexistente: " .. s.id)
		end
	end

	local inCase = {}
	for _, c in ipairs(CaseDefinitions.List) do
		if type(c.price) ~= "number" or c.price <= 0 then
			err(c.id, c.id .. ": preço inválido")
		end
		if type(c.requiredLevel) ~= "number" or c.requiredLevel < 1 or c.requiredLevel > ProgressionConfig.MaxLevel then
			err(c.id, c.id .. ": nível exigido fora do intervalo")
		end
		if #c.drops == 0 then
			err(c.id, c.id .. ": sem recompensas")
		end
		local total = 0
		for _, d in ipairs(c.drops) do
			if not SkinDefinitions.ById[d.skinId] then
				err(c.id, c.id .. ": referência a skin inexistente " .. tostring(d.skinId))
			end
			if type(d.weight) ~= "number" or d.weight <= 0 or d.weight ~= d.weight then
				err(c.id, c.id .. ": peso inválido para " .. tostring(d.skinId))
			else
				total = total + d.weight
			end
			inCase[d.skinId] = true
		end
		if not badCases[c.id] then
			for _, luck in ipairs({ 0, LuckConfig.MaxTotalLuck }) do
				local sum = 0
				for _, e in ipairs(Probability.computeTable(c, luck)) do
					sum = sum + e.probability
				end
				if math.abs(sum - 1) > 1e-9 then
					err(c.id, c.id .. ": probabilidades não somam 100%")
				end
			end
		end
	end
	for _, s in ipairs(SkinDefinitions.List) do
		if not inCase[s.id] then
			err(nil, "skin fora de qualquer caixa: " .. s.id)
		end
	end

	-- referências em recompensas
	local function checkReward(where, r)
		if type(r) ~= "table" then
			return
		end
		for caseId in pairs(r.freeCases or {}) do
			if not CaseDefinitions.ById[caseId] then
				err(nil, where .. ": caixa grátis inexistente " .. caseId)
			end
		end
		if r.title and not ProgressionConfig.Titles[r.title] then
			err(nil, where .. ": título inexistente " .. r.title)
		end
		if r.luck and not LuckConfig.Modifiers[r.luck] then
			err(nil, where .. ": bônus de sorte inexistente " .. r.luck)
		end
		for id in pairs(r.potions or {}) do
			if not PotionConfig.Potions[id] then
				err(nil, where .. ": poção inexistente " .. id)
			end
		end
	end
	for level, r in pairs(ProgressionConfig.LevelRewards) do
		checkReward("recompensa de nível " .. tostring(level), r)
	end
	for i, r in ipairs(ProgressionConfig.DailyRewards) do
		checkReward("presente diário " .. i, r)
	end
	for colId, r in pairs(ProgressionConfig.CollectionRewards) do
		if not CaseDefinitions.ById[colId] then
			err(nil, "recompensa de coleção inexistente: " .. colId)
		end
		checkReward("coleção " .. colId, r)
	end
	for _, c in ipairs(CaseDefinitions.Collections) do
		if not ProgressionConfig.CollectionRewards[c.id] then
			err(nil, "coleção sem recompensa: " .. c.id)
		end
	end
	for id, m in pairs(MissionDefinitions.ById) do
		checkReward("missão " .. id, m.reward)
	end
	for _, a in ipairs(AchievementDefinitions.List) do
		checkReward("conquista " .. a.id, a.reward)
	end
	for _, ev in ipairs(EventDefinitions.Events) do
		if ev.endsAt <= ev.startsAt then
			err(nil, "evento com datas inválidas: " .. ev.id)
		end
		if ev.featuredCollection and not CaseDefinitions.ById[ev.featuredCollection] then
			err(nil, "evento com coleção inexistente: " .. ev.id)
		end
		for _, ch in ipairs(ev.challenges) do
			checkReward("desafio " .. ch.id, ch.reward)
		end
	end
	for _, colId in ipairs(EventDefinitions.WeeklyFeaturedRotation) do
		if not CaseDefinitions.ById[colId] then
			err(nil, "rotação semanal com coleção inexistente: " .. colId)
		end
	end
	for _, z in ipairs(ZoneConfig.Zones) do
		if z.requires and not ZoneConfig.ById[z.requires] then
			err(nil, "zona exige zona inexistente: " .. z.id)
		end
	end
	for _, c in ipairs(CaseDefinitions.List) do
		if #c.drops < 2 then
			err(c.id, c.id .. ": caixa precisa de pelo menos 2 recompensas")
		end
	end
	return errors, badCases
end

return DropValidator
