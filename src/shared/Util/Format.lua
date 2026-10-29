-- Format: formatação de números e tempo para a interface.

local Format = {}

local function groupDigits(intStr)
	local out = intStr
	local k
	repeat
		out, k = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1.%2")
	until k == 0
	return out
end

-- 1234567 -> "1.234.567"
function Format.int(n)
	n = math.floor((n or 0) + 0.5)
	return groupDigits(string.format("%.0f", n))
end

-- 1234567 -> "1,23 mi" (abreviado, padrão brasileiro)
function Format.short(n)
	n = n or 0
	local abs = math.abs(n)
	local suffixes = {
		{ 1e12, " tri" },
		{ 1e9, " bi" },
		{ 1e6, " mi" },
		{ 1e3, " mil" },
	}
	for _, s in ipairs(suffixes) do
		if abs >= s[1] then
			local v = n / s[1]
			local str = string.format("%.2f", v)
			str = string.gsub(str, "%.?0+$", "")
			str = string.gsub(str, "%.", ",")
			return str .. s[2]
		end
	end
	return Format.int(n)
end

function Format.credits(n)
	return "$ " .. Format.short(n)
end

-- 0.0123 -> "1,230%" (3 casas)
function Format.percent(p, decimals)
	decimals = decimals or 3
	local str = string.format("%." .. decimals .. "f", p * 100)
	str = string.gsub(str, "%.", ",")
	return str .. "%"
end

function Format.rate(perSecond)
	local str = string.format("%.2f", perSecond)
	str = string.gsub(str, "%.", ",")
	return str .. "/s"
end

function Format.duration(seconds)
	seconds = math.max(0, math.floor(seconds))
	local d = math.floor(seconds / 86400)
	local h = math.floor((seconds % 86400) / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if d > 0 then
		return d .. "d " .. h .. "h"
	elseif h > 0 then
		return h .. "h " .. m .. "min"
	elseif m > 0 then
		return m .. "min " .. s .. "s"
	end
	return s .. "s"
end

return Format
