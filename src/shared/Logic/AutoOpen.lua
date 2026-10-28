-- AutoOpen: estado de uma sessão de abertura automática (lado do servidor).
-- A sessão termina sozinha ao atingir o limite de aberturas ou de duração,
-- e pode ser interrompida imediatamente a qualquer momento.

local Shared = script.Parent.Parent
local EconomyConfig = require(Shared.Config.EconomyConfig)

local AutoOpen = {}
AutoOpen.__index = AutoOpen

function AutoOpen.new()
	return setmetatable({ active = false, caseId = nil, quantity = 1, startedAt = 0, opens = 0, lastOpenAt = -math.huge, stopReason = nil }, AutoOpen)
end

function AutoOpen:start(caseId, quantity, now)
	self.active = true
	self.caseId = caseId
	self.quantity = quantity
	self.startedAt = now
	self.opens = 0
	self.stopReason = nil
end

function AutoOpen:stop(reason)
	self.active = false
	self.stopReason = reason or "stopped"
end

-- Verifica se a próxima abertura automática pode ocorrer agora.
-- Retorna (podeAbrir, motivoSeNao)
function AutoOpen:check(caseId, quantity, now)
	local cfg = EconomyConfig.Opening
	if not self.active then
		return false, "auto_inactive"
	end
	if caseId ~= self.caseId or quantity ~= self.quantity then
		return false, "auto_mismatch"
	end
	if self.opens >= cfg.AutoMaxOpensPerSession then
		self:stop("auto_limit_opens")
		return false, "auto_limit_opens"
	end
	if now - self.startedAt >= cfg.AutoMaxSessionSeconds then
		self:stop("auto_limit_time")
		return false, "auto_limit_time"
	end
	if now - self.lastOpenAt < cfg.AutoMinInterval then
		return false, "auto_too_fast"
	end
	return true, nil
end

function AutoOpen:record(now)
	self.opens = self.opens + 1
	self.lastOpenAt = now
end

return AutoOpen
