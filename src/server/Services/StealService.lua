-- StealService: roubo de criaturas entre jogadores (sem dano, sem PvP de combate).
--
-- Como funciona:
-- 1. Na base de outro jogador (sem escudo), segure o botão "Roubar" em uma criatura.
-- 2. A criatura vai para a cabeça de quem roubou (anda mais devagar) e o dono é avisado.
-- 3. Se o dono ENCOSTAR em quem está carregando, a criatura volta (defesa).
-- 4. Se quem rouba entrar na própria base, a criatura muda de dono (operação atômica
--    nos dois perfis + salvamento rápido dos dois).
-- 5. Tempo esgotado, personagem morto/reiniciado ou alguém saindo do servidor: ela volta.
--
-- Tudo é validado no servidor: posições, escudo, proteção pós-roubo e vagas livres.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local MapConfig = require(Shared.Config.MapConfig)
local ProfileOps = require(Shared.Logic.ProfileOps)
local CreatureModel = require(Shared.Visual.CreatureModel)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local BaseService = require(script.Parent.BaseService)

local StealService = {}

local carries = {} -- [thief] = { victim, uid, speciesId, mutationId, startedAt, endsAt, model }
local lockedBy = {} -- [victim] = { [uid] = thief }

local function creatureName(c)
	local s = GameConfig.SpeciesById[c.s or c.speciesId]
	local mId = c.m or c.mutationId
	local m = GameConfig.Mutations[mId]
	return (mId ~= "normal" and (m.name .. " ") or "") .. s.name
end

function StealService.carrying(player)
	local c = carries[player]
	if not c then
		return nil
	end
	return { victim = c.victim.DisplayName, speciesId = c.speciesId, mutationId = c.mutationId, endsAt = c.endsAt }
end

local function lockedFor(victim)
	local out = {}
	for uid in pairs(lockedBy[victim] or {}) do
		out[uid] = true
	end
	return out
end

local function attachModel(thief, c)
	local root = BaseService.root(thief)
	if not root then
		return nil
	end
	local model = CreatureModel.build(c.s, c.m, { anchored = false })
	model.Name = "CarriedCreature"
	local h = CreatureModel.size(c.s)
	model:PivotTo(root.CFrame * CFrame.new(0, 3 + h / 2, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model.Parent = thief.Character
	return model
end

-- encerra um roubo; reason = "delivered" | "tagged" | "timeout" | "cancel"
local function finish(thief, reason)
	local c = carries[thief]
	if not c then
		return
	end
	carries[thief] = nil
	if lockedBy[c.victim] then
		lockedBy[c.victim][c.uid] = nil
	end
	if c.model then
		c.model:Destroy()
	end
	BaseService.setHidden(c.victim, c.uid, false)
	if reason ~= "delivered" then
		BaseService.render(c.victim)
	end
	PlayerDataService.push(thief)
	PlayerDataService.push(c.victim)
end

function StealService.begin(thief, victim, uid)
	if not victim or not victim.Parent or victim == thief then
		return Remotes.fail("invalid_request", "Você não pode roubar da própria base.")
	end
	local thiefProfile = PlayerDataService.getProfile(thief)
	local victimProfile = PlayerDataService.getProfile(victim)
	if not thiefProfile or not victimProfile then
		return Remotes.fail("not_loaded", "Dados carregando.")
	end
	if carries[thief] then
		return Remotes.fail("already_carrying", "Você já está carregando uma criatura.")
	end
	if lockedBy[victim] and lockedBy[victim][uid] then
		return Remotes.fail("being_stolen", "Outra pessoa já está carregando essa criatura.")
	end
	local now = PlayerDataService.now()
	local victimBase = BaseService.baseIndex(victim)
	if not victimBase or BaseService.isShielded(victimBase, now) then
		return Remotes.fail("shielded", "Essa base está com o escudo ligado.")
	end
	-- quem rouba precisa estar dentro da base da vítima, perto da criatura
	local pos = BaseService.position(thief)
	local c = victimProfile.creatures[uid]
	if not pos or not c or MapConfig.baseAt(pos.X, pos.Z) ~= victimBase then
		return Remotes.fail("too_far", "Chegue mais perto da criatura.")
	end
	local px, pz = MapConfig.padPosition(victimBase, c.pad)
	local dx, dz = pos.X - px, pos.Z - pz
	local maxD = GameConfig.Steal.PromptDistance + 3
	if dx * dx + dz * dz > maxD * maxD then
		return Remotes.fail("too_far", "Chegue mais perto da criatura.")
	end
	local ok, code = ProfileOps.canSteal(victimProfile, thiefProfile, uid, now)
	if not ok then
		return Remotes.fail(code, ProfileOps.Messages[code])
	end
	local carry = {
		victim = victim,
		uid = uid,
		speciesId = c.s,
		mutationId = c.m,
		startedAt = now,
		endsAt = now + GameConfig.Steal.MaxCarrySeconds,
	}
	carries[thief] = carry
	lockedBy[victim] = lockedBy[victim] or {}
	lockedBy[victim][uid] = thief
	BaseService.setHidden(victim, uid, true)
	carry.model = attachModel(thief, c)
	local name = creatureName(c)
	BaseService.notify(victim, "theft", "🚨 " .. thief.DisplayName .. " pegou seu " .. name .. "! Encoste nele para recuperar!", { thief = thief.DisplayName })
	BaseService.notify(thief, "carry", "🏃 Leve " .. name .. " para a SUA base em " .. GameConfig.Steal.MaxCarrySeconds .. "s!")
	PlayerDataService.push(thief)
	PlayerDataService.push(victim)
	return { ok = true, data = { uid = uid } }
end

local function deliver(thief, c)
	local res = PlayerDataService.runPair(c.victim, thief, function(victimProfile, thiefProfile, ctx)
		return ProfileOps.completeSteal(victimProfile, thiefProfile, c.uid, ctx.now)
	end)
	finish(thief, "delivered")
	if res.ok then
		local name = creatureName(res.data.creature)
		BaseService.notify(thief, "good", "😈 Você roubou " .. name .. "!")
		BaseService.notify(c.victim, "theft", "😭 " .. thief.DisplayName .. " levou seu " .. name .. ". Você recebeu o que ele tinha guardado.")
	else
		BaseService.notify(thief, "error", res.message or "Não foi possível concluir o roubo.")
	end
	return res
end

-- verificação periódica de todos os roubos em andamento
function StealService.tick(now)
	for thief, c in pairs(carries) do
		local tpos = BaseService.position(thief)
		local char = thief.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not thief.Parent or not c.victim.Parent or not tpos or (hum and hum.Health <= 0) then
			finish(thief, "cancel")
			if c.victim.Parent then
				BaseService.notify(c.victim, "good", "✅ Sua criatura voltou para a base.")
			end
		elseif now >= c.endsAt then
			finish(thief, "timeout")
			BaseService.notify(thief, "error", "⌛ Tempo esgotado! A criatura voltou para a base do dono.")
			BaseService.notify(c.victim, "good", "✅ O ladrão demorou demais. Sua criatura voltou!")
		else
			local vpos = BaseService.position(c.victim)
			local tag = GameConfig.Steal.TagDistance
			if vpos and ((vpos.X - tpos.X) ^ 2 + (vpos.Z - tpos.Z) ^ 2) <= tag * tag then
				finish(thief, "tagged")
				PlayerDataService.run(c.victim, function(profile, ctx)
					ProfileOps.recordDefense(profile, ctx.now)
					return true, {}
				end)
				BaseService.notify(c.victim, "good", "🛡️ Você pegou " .. thief.DisplayName .. "! A criatura voltou.")
				BaseService.notify(thief, "error", "🙀 " .. c.victim.DisplayName .. " te pegou! A criatura voltou para a base dele.")
			elseif MapConfig.inDelivery(BaseService.baseIndex(thief), tpos.X, tpos.Z) then
				deliver(thief, c)
			end
		end
	end
end

function StealService.init()
	BaseService.carryingProvider = StealService.carrying
	BaseService.shieldHook = function(owner, baseIndex)
		for thief, c in pairs(carries) do
			local pos = BaseService.position(thief)
			if c.victim == owner and pos and MapConfig.baseAt(pos.X, pos.Z) == baseIndex then
				finish(thief, "cancel")
				BaseService.notify(thief, "error", "🛡️ O escudo ligou com você dentro! A criatura voltou.")
				BaseService.notify(owner, "good", "🛡️ Escudo ligado a tempo: sua criatura voltou!")
			end
		end
	end
	PlayerDataService.setLockProvider(lockedFor)
	BaseService.promptHandlers.Steal = function(prompt, player)
		local ownerId = prompt:GetAttribute("OwnerUserId")
		local victim = Players:GetPlayerByUserId(ownerId)
		local res = StealService.begin(player, victim, prompt:GetAttribute("Uid"))
		if not res.ok then
			BaseService.notify(player, "error", res.message)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		-- quem sai no meio de um roubo: a criatura volta; quem é roubado e sai: o roubo é cancelado
		finish(player, "cancel")
		for thief, c in pairs(carries) do
			if c.victim == player then
				finish(thief, "cancel")
				BaseService.notify(thief, "error", "O dono saiu do servidor. A criatura voltou.")
			end
		end
		lockedBy[player] = nil
	end)
end

function StealService.start()
	task.spawn(function()
		while true do
			task.wait(0.2)
			StealService.tick(PlayerDataService.now())
		end
	end)
end

StealService._carries = carries

return StealService
