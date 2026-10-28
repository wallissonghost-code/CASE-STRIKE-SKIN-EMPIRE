-- TimeUtil: dias e semanas em UTC. Sempre alimentado pelo relógio do SERVIDOR.

local TimeUtil = {}

local DAY = 86400
local WEEK = 604800
local MONDAY_EPOCH = 345600 -- 1970-01-05 00:00 UTC (segunda-feira)

function TimeUtil.dayIndex(now)
	return math.floor(now / DAY)
end

function TimeUtil.weekIndex(now)
	return math.floor((now - MONDAY_EPOCH) / WEEK)
end

function TimeUtil.secondsUntilNextDay(now)
	return (TimeUtil.dayIndex(now) + 1) * DAY - now
end

function TimeUtil.secondsUntilNextWeek(now)
	return MONDAY_EPOCH + (TimeUtil.weekIndex(now) + 1) * WEEK - now
end

return TimeUtil
