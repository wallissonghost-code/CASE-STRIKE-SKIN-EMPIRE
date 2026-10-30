-- Relógio único do jogo (UTC). Usar sempre este módulo para datas de missões e presentes.

local TimeUtil = {}

function TimeUtil.now()
	return DateTime.now().UnixTimestamp
end

function TimeUtil.day(t)
	return math.floor((t or TimeUtil.now()) / 86400)
end

function TimeUtil.secondsToNextDay(t)
	t = t or TimeUtil.now()
	return (TimeUtil.day(t) + 1) * 86400 - t
end

function TimeUtil.hour(t)
	return math.floor((t or TimeUtil.now()) / 3600)
end

return TimeUtil
