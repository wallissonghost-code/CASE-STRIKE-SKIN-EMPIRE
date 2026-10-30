-- Formatação de números e tempos para a interface.

local Format = {}

-- 1234567 -> "1.234.567"
function Format.int(n)
	n = math.floor(tonumber(n) or 0)
	local negative = n < 0
	local s = string.format("%d", math.abs(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1.")))
	if string.sub(out, 1, 1) == "." then
		out = string.sub(out, 2)
	end
	return (negative and "-" or "") .. out
end

-- 1500 -> "1,5 mil"; 2500000 -> "2,5 mi"
function Format.short(n)
	n = tonumber(n) or 0
	local function trim(x)
		local s = string.format("%.1f", x)
		s = string.gsub(s, "%.0$", "")
		return (string.gsub(s, "%.", ","))
	end
	if n >= 1000000 then
		return trim(n / 1000000) .. " mi"
	elseif n >= 10000 then
		return trim(n / 1000) .. " mil"
	end
	return Format.int(n)
end

function Format.percent(p)
	if p >= 10 or p == math.floor(p) then
		return string.format("%d%%", math.floor(p + 0.5))
	end
	local s = string.format("%.2f", p)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	return (string.gsub(s, "%.", ",")) .. "%"
end

function Format.duration(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%dm %02ds", m, s)
end

return Format
