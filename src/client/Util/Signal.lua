-- Sinal simples para eventos locais do cliente.

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(fn)
	table.insert(self.handlers, fn)
	local handlers = self.handlers
	return {
		Disconnect = function()
			local i = table.find(handlers, fn)
			if i then
				table.remove(handlers, i)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, fn in ipairs(self.handlers) do
		task.spawn(fn, ...)
	end
end

return Signal
