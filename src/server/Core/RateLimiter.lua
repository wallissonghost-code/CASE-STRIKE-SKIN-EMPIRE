-- RateLimiter: balde de fichas por jogador e por categoria de ação.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)

local RateLimiter = {}

local buckets = {} -- [player] = { [category] = { tokens, last } }

function RateLimiter.allow(player, category)
	local cfg = EconomyConfig.RateLimits[category]
	if not cfg then
		return true
	end
	local now = os.clock()
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local b = perPlayer[category]
	if not b then
		b = { tokens = cfg.capacity, last = now }
		perPlayer[category] = b
	end
	b.tokens = math.min(cfg.capacity, b.tokens + (now - b.last) * cfg.refillPerSecond)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens = b.tokens - 1
	return true
end

function RateLimiter.clear(player)
	buckets[player] = nil
end

return RateLimiter
