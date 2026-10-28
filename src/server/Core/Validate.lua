-- Validate: verificação de tipos dos dados recebidos do cliente.
-- Apenas ids, quantidades e flags são aceitos; nenhum valor econômico vem do cliente.

local Validate = {}

function Validate.id(v, maxLen)
	return type(v) == "string" and #v > 0 and #v <= (maxLen or 64) and not string.find(v, "[^%w_%-]")
end

function Validate.bool(v)
	return v == true
end

function Validate.int(v, min, max)
	return type(v) == "number" and v == v and v == math.floor(v) and v >= min and v <= max
end

function Validate.idList(v, maxCount)
	if type(v) ~= "table" then
		return false
	end
	local n = #v
	if n == 0 or n > maxCount then
		return false
	end
	local count = 0
	for k, item in pairs(v) do
		count = count + 1
		if type(k) ~= "number" or not Validate.id(item, 24) then
			return false
		end
	end
	return count == n
end

return Validate
