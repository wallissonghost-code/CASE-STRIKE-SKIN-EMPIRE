-- Limite de frequência por jogador e categoria (balde de fichas).

local RateLimiter = {}

RateLimiter.Categories = {
	machine = { rate = 2, burst = 3 },
	inventory = { rate = 6, burst = 10 },
	upgrade = { rate = 3, burst = 5 },
	progress = { rate = 4, burst = 8 },
}

local buckets = {} -- [player][category] = { tokens, at }

function RateLimiter.allow(player, category)
	local cfg = RateLimiter.Categories[category] or RateLimiter.Categories.progress
	local byPlayer = buckets[player]
	if not byPlayer then
		byPlayer = {}
		buckets[player] = byPlayer
	end
	local now = os.clock()
	local b = byPlayer[category]
	if not b then
		b = { tokens = cfg.burst, at = now }
		byPlayer[category] = b
	end
	b.tokens = math.min(cfg.burst, b.tokens + (now - b.at) * cfg.rate)
	b.at = now
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
