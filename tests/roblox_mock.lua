-- Ambiente Roblox simulado (mínimo) para executar o SERVIDOR real fora do Studio:
-- instâncias, serviços, DataStore em memória (com UpdateAsync e falhas simuláveis),
-- agendador de tarefas com relógio virtual. Usado por tests/server_smoke.lua.

local M = {}

---------------------------------------------------------------------------
-- relógio virtual e agendador
---------------------------------------------------------------------------
M.clock = 0
M.epoch = 1793000000
local queue = {} -- { at, co, args }

local function schedule(at, co, ...)
	table.insert(queue, { at = at, co = co, args = table.pack(...) })
end

local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error("erro em tarefa: " .. tostring(err) .. "\n" .. debug.traceback(co), 0)
	end
end

task = {
	spawn = function(fn, ...)
		local co = type(fn) == "thread" and fn or coroutine.create(fn)
		resume(co, ...)
		return co
	end,
	defer = function(fn, ...)
		local co = coroutine.create(fn)
		schedule(M.clock, co, ...)
		return co
	end,
	delay = function(t, fn, ...)
		local co = coroutine.create(fn)
		schedule(M.clock + (t or 0), co, ...)
		return co
	end,
	wait = function(t)
		local co = coroutine.running()
		local start = M.clock
		schedule(M.clock + (t or 0.03), co)
		coroutine.yield()
		return M.clock - start
	end,
}
wait = task.wait

-- executa tarefas até o relógio alcançar `untilTime`
function M.advance(seconds)
	local target = M.clock + seconds
	while true do
		table.sort(queue, function(a, b)
			return a.at < b.at
		end)
		local nextItem = queue[1]
		if not nextItem or nextItem.at > target then
			break
		end
		table.remove(queue, 1)
		if nextItem.at > M.clock then
			M.clock = nextItem.at
		end
		if coroutine.status(nextItem.co) == "suspended" then
			resume(nextItem.co, table.unpack(nextItem.args, 1, nextItem.args.n))
		end
	end
	M.clock = target
end

-- roda uma função como se fosse uma tarefa e avança o tempo até ela terminar
function M.run(fn, maxSeconds)
	local done, result = false, nil
	task.spawn(function()
		result = table.pack(fn())
		done = true
	end)
	local waited = 0
	while not done and waited < (maxSeconds or 120) do
		M.advance(0.1)
		waited = waited + 0.1
	end
	assert(done, "tarefa não terminou")
	return table.unpack(result, 1, result.n)
end

os.clock = function()
	return M.clock
end

---------------------------------------------------------------------------
-- tipos de dados
---------------------------------------------------------------------------
local Vec = {}
Vec.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return Vector3.new(v.X / m, v.Y / m, v.Z / m)
	end
	return rawget(Vec, k)
end
Vec.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vec.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vec.__mul = function(a, b)
	if type(a) == "number" then
		return Vector3.new(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vec.__div = function(a, b)
	return Vector3.new(a.X / b, a.Y / b, a.Z / b)
end
Vec.__unm = function(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vec)
	end,
}
Vector2 = { new = function(x, y)
	return { X = x or 0, Y = y or 0 }
end }

local CF = {}
CF.__index = CF
CF.__mul = function(a, b)
	if getmetatable(b) == Vec then
		return a.Position + b
	end
	return setmetatable({ Position = a.Position + b.Position }, CF)
end
CF.__add = function(a, v)
	return setmetatable({ Position = a.Position + v }, CF)
end
CFrame = {
	new = function(x, y, z)
		if type(x) == "table" then
			return setmetatable({ Position = x }, CF)
		end
		return setmetatable({ Position = Vector3.new(x, y, z) }, CF)
	end,
	Angles = function()
		return setmetatable({ Position = Vector3.new() }, CF)
	end,
	lookAt = function(p)
		return setmetatable({ Position = p }, CF)
	end,
}

local C3 = {}
C3.__index = C3
function C3:Lerp(other, t)
	return Color3.new(self.R + (other.R - self.R) * t, self.G + (other.G - self.G) * t, self.B + (other.B - self.B) * t)
end
function C3:ToHex()
	return "FFFFFF"
end
Color3 = {
	fromHSV = function(h, s, v)
		return setmetatable({ R = v, G = v * (1 - s), B = v * (1 - s * h) }, C3)
	end,
	new = function(r, g, b)
		return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
	end,
	fromRGB = function(r, g, b)
		return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, C3)
	end,
}

local function opaqueLib(name)
	return setmetatable({}, {
		__index = function(_, fname)
			return function(...)
				return { __opaque = name .. "." .. fname, args = { ... } }
			end
		end,
	})
end
UDim2 = opaqueLib("UDim2")
NumberRange = opaqueLib("NumberRange")
NumberSequence = opaqueLib("NumberSequence")
UDim = opaqueLib("UDim")
ColorSequence = opaqueLib("ColorSequence")
TweenInfo = opaqueLib("TweenInfo")

local function enumProxy(path)
	return setmetatable({}, {
		__index = function(_, k)
			return path .. "." .. k
		end,
	})
end
Enum = setmetatable({}, {
	__index = function(_, k)
		return enumProxy("Enum." .. k)
	end,
})

DateTime = {
	now = function()
		return { UnixTimestamp = math.floor(M.epoch + M.clock) }
	end,
}

local rngSeed = 12345
Random = {
	new = function(seed)
		local s = seed or rngSeed
		rngSeed = rngSeed + 1
		s = (math.floor(s) % 2147483646) + 1
		local r = {}
		function r:NextNumber(a, b)
			s = (s * 16807) % 2147483647
			local x = s / 2147483647
			if a then
				return a + (b - a) * x
			end
			return x
		end
		function r:NextInteger(a, b)
			return a + math.floor(self:NextNumber() * (b - a + 1))
		end
		return r
	end,
}

---------------------------------------------------------------------------
-- sinais e instâncias
---------------------------------------------------------------------------
local function newSignal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, h in ipairs(self.handlers) do
			task.spawn(h, ...)
		end
	end
	function s:Wait()
		return task.wait(1 / 60)
	end
	return s
end
M.newSignal = newSignal

local Inst = {}
local SIGNALS = { Destroying = true, Triggered = true, Activated = true, InputBegan = true, InputEnded = true, InputChanged = true, MouseButton1Click = true, OnClientEvent = true, DescendantAdded = true, ChildAdded = true }
local BASE_PART = { Part = true, WedgePart = true, SpawnLocation = true }
local GUI_OBJECT = { Frame = true, TextLabel = true, TextButton = true, TextBox = true, ScrollingFrame = true, ViewportFrame = true, ImageLabel = true, ImageButton = true }

local function isA(self, class)
	local c = rawget(self, "__class")
	if c == class then
		return true
	end
	if class == "BasePart" and BASE_PART[c] then
		return true
	end
	if class == "GuiObject" and GUI_OBJECT[c] then
		return true
	end
	if class == "Instance" then
		return true
	end
	return false
end

local methods = {}
function methods:FindFirstChild(name)
	for _, c in ipairs(rawget(self, "__children")) do
		if c.Name == name then
			return c
		end
	end
	return nil
end
function methods:FindFirstChildOfClass(class)
	for _, c in ipairs(rawget(self, "__children")) do
		if rawget(c, "__class") == class then
			return c
		end
	end
	return nil
end
function methods:WaitForChild(name)
	return self:FindFirstChild(name) or error("WaitForChild: filho inexistente " .. tostring(name) .. " em " .. tostring(self.Name))
end
function methods:GetChildren()
	local out = {}
	for i, c in ipairs(rawget(self, "__children")) do
		out[i] = c
	end
	return out
end
function methods:GetDescendants()
	local out = {}
	local function walk(n)
		for _, c in ipairs(rawget(n, "__children")) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
methods.IsA = isA
function methods:SetAttribute(k, v)
	rawget(self, "__attrs")[k] = v
end
function methods:GetAttribute(k)
	return rawget(self, "__attrs")[k]
end
function methods:Destroy()
	self.Parent = nil
end
function methods:PivotTo(cf)
	rawset(self, "__pivot", cf)
end
function methods:GetPivot()
	return rawget(self, "__pivot") or CFrame.new(0, 0, 0)
end
function methods:GetBoundingBox()
	return CFrame.new(0, 0, 0), Vector3.new(2, 1, 1)
end
function methods:ScaleTo() end
local function wire(v)
	-- simula a serialização do Roblox: copia e remove funções
	if type(v) == "function" then
		return nil
	end
	if type(v) ~= "table" or getmetatable(v) ~= nil then
		return v
	end
	local o = {}
	for k, x in pairs(v) do
		o[k] = wire(x)
	end
	return o
end
M.wire = wire
function methods:FireClient(player, data)
	table.insert(M.fired, { remote = self.Name, player = player, data = data })
	if M.localPlayer and player == M.localPlayer then
		self.OnClientEvent:Fire(wire(data))
	end
end
function methods:FireAllClients(data)
	table.insert(M.fired, { remote = self.Name, all = true, data = data })
	if M.localPlayer then
		self.OnClientEvent:Fire(wire(data))
	end
end
function methods:InvokeServer(payload)
	task.wait(0.02)
	local fn = rawget(self, "__props").OnServerInvoke
	return wire(fn(M.localPlayer, wire(payload)))
end
function methods:GetPropertyChangedSignal()
	return newSignal()
end
M.fired = {}

Inst.__index = function(self, k)
	local m = methods[k]
	if m then
		return m
	end
	local props = rawget(self, "__props")
	if props[k] ~= nil then
		return props[k]
	end
	local child = methods.FindFirstChild(self, k)
	if child then
		return child
	end
	if SIGNALS[k] then
		props[k] = newSignal()
		return props[k]
	end
	return nil
end
Inst.__newindex = function(self, k, v)
	local props = rawget(self, "__props")
	if k == "Parent" then
		local old = props.Parent
		if old then
			local list = rawget(old, "__children")
			for i, c in ipairs(list) do
				if c == self then
					table.remove(list, i)
					break
				end
			end
		end
		props.Parent = v
		if v then
			table.insert(rawget(v, "__children"), self)
		end
		return
	end
	props[k] = v
end

function M.instance(class, name)
	local i = setmetatable({ __class = class, __props = {}, __children = {}, __attrs = {} }, Inst)
	i.Name = name or class
	if class == "NumberValue" or class == "IntValue" then
		i.Value = 0
	end
	return i
end
Instance = {
	new = function(class)
		return M.instance(class)
	end,
}

---------------------------------------------------------------------------
-- DataStore em memória
---------------------------------------------------------------------------
M.datastore = {} -- [store][key] = valor (cópia serializada)
M.failNext = 0 -- número de chamadas que devem falhar
M.updateCalls = 0

local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local o = {}
	for k, x in pairs(v) do
		o[k] = deepCopy(x)
	end
	return o
end

local function newStore(name, ordered)
	M.datastore[name] = M.datastore[name] or {}
	local data = M.datastore[name]
	local s = {}
	function s:GetAsync(key)
		task.wait(0.05)
		return deepCopy(data[key])
	end
	function s:SetAsync(key, value)
		task.wait(0.05)
		data[key] = deepCopy(value)
	end
	function s:UpdateAsync(key, fn)
		M.updateCalls = M.updateCalls + 1
		task.wait(0.05)
		if M.failNext > 0 then
			M.failNext = M.failNext - 1
			error("502: DataStore simulado indisponível")
		end
		local result = fn(deepCopy(data[key]))
		if result ~= nil then
			data[key] = deepCopy(result)
			return deepCopy(result)
		end
		return nil
	end
	function s:GetSortedAsync(asc, n)
		local rows = {}
		for k, v in pairs(data) do
			table.insert(rows, { key = k, value = v })
		end
		table.sort(rows, function(a, b)
			return a.value > b.value
		end)
		return {
			GetCurrentPage = function()
				local out = {}
				for i = 1, math.min(n, #rows) do
					out[i] = rows[i]
				end
				return out
			end,
		}
	end
	return s
end

---------------------------------------------------------------------------
-- serviços e game
---------------------------------------------------------------------------
function M.newGame(jobId)
	local services = {}
	local g = M.instance("DataModel", "Game")
	rawset(g, "JobId", jobId or "job-1")
	local function svc(name)
		local s = M.instance(name, name)
		s.Parent = g
		services[name] = s
		return s
	end
	local RS = svc("ReplicatedStorage")
	svc("ServerScriptService")
	svc("Lighting")
	local ws = svc("Workspace")
	workspace = ws

	local Players = svc("Players")
	rawset(Players, "PlayerAdded", newSignal())
	rawset(Players, "PlayerRemoving", newSignal())
	rawset(Players, "GetPlayers", function()
		local out = {}
		for _, p in pairs(M.players) do
			if p.Parent then
				table.insert(out, p)
			end
		end
		return out
	end)
	rawset(Players, "GetPlayerByUserId", function(_, id)
		for _, p in pairs(M.players) do
			if p.UserId == id and p.Parent then
				return p
			end
		end
	end)
	rawset(Players, "GetNameFromUserIdAsync", function(_, id)
		return "User" .. id
	end)

	services.DataStoreService = {
		GetDataStore = function(_, name)
			return newStore(name, false)
		end,
		GetOrderedDataStore = function(_, name)
			return newStore(name, true)
		end,
	}
	local camera = M.instance("Camera", "Camera")
	camera.ViewportSize = Vector2.new(1280, 720)
	camera.Parent = ws
	ws.CurrentCamera = camera
	services.TweenService = { Create = function(_, inst, info, goal)
		return {
			Play = function()
				for k, v in pairs(goal) do
					inst[k] = v
				end
			end,
			Cancel = function() end,
		}
	end }
	services.UserInputService = { InputBegan = newSignal(), TouchEnabled = false }
	services.StarterGui = { SetCoreGuiEnabled = function() end }
	services.ProximityPromptService = { PromptTriggered = newSignal() }
	services.RunService = { IsStudio = function()
		return false
	end, RenderStepped = newSignal(), Heartbeat = newSignal() }
	local guid = 0
	services.HttpService = { GenerateGUID = function()
		guid = guid + 1
		return string.format("00000000-0000-0000-0000-%012d", guid)
	end }
	M.closeHandlers = {}
	rawset(g, "GetService", function(_, name)
		return services[name] or error("serviço não simulado: " .. name)
	end)
	rawset(g, "BindToClose", function(_, fn)
		table.insert(M.closeHandlers, fn)
	end)
	game = g
	M.services = services
	M.players = {}
	return g, RS
end

function M.newPlayer(userId, name)
	local p = M.instance("Player", name)
	p.UserId = userId
	p.DisplayName = name
	rawset(p, "CharacterAdded", newSignal())
	rawset(p, "Kick", function(self, msg)
		self.kicked = msg
		self.Parent = nil
	end)
	local gui = M.instance("PlayerGui", "PlayerGui")
	gui.Parent = p
	p.Parent = game:GetService("Players")
	M.players[userId] = p
	return p
end

function M.removePlayer(p)
	game:GetService("Players").PlayerRemoving:Fire(p)
	p.Parent = nil
end

function M.addPlayer(p)
	game:GetService("Players").PlayerAdded:Fire(p)
end

return M
