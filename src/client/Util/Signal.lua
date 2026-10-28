-- Signal: eventos simples entre controladores do cliente.

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local entry = { fn = fn, connected = true }
	table.insert(self.handlers, entry)
	return {
		Disconnect = function()
			entry.connected = false
			for i, h in ipairs(self.handlers) do
				if h == entry then
					table.remove(self.handlers, i)
					break
				end
			end
		end,
	}
end

function Signal:Fire(...)
	local list = {}
	for i, h in ipairs(self.handlers) do
		list[i] = h
	end
	for _, h in ipairs(list) do
		if h.connected then
			task.spawn(h.fn, ...)
		end
	end
end

return Signal
