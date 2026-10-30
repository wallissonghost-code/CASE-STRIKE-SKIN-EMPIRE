-- Rankings: maior valor de coleção, mais objetos descobertos, maior nível e mais conquistas.
-- * Servidor: calculado da memória a cada 15 s (sem DataStore).
-- * Global: OrderedDataStore com escrita no máximo a cada LeaderboardWriteInterval por jogador
--   (só se o valor mudou) e leitura do top a cada LeaderboardRefresh, guardada em cache.
-- Os clientes recebem o cache por LeaderboardUpdated; o painel 3D do parque usa o mesmo cache.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared.EconomyConfig)
local ProfileOps = require(Shared.Logic.ProfileOps)
local Format = require(Shared.Util.Format)
local Remotes = require(script.Parent.Parent.Core.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local MapService = require(script.Parent.MapService)

local LeaderboardService = {}

LeaderboardService.Boards = {
	{ id = "value", name = "Valor da coleção", metric = ProfileOps.collectionValue },
	{ id = "discovered", name = "Descobertas", metric = ProfileOps.discoveredCount },
	{ id = "level", name = "Nível", metric = ProfileOps.level },
	{ id = "achievements", name = "Conquistas", metric = ProfileOps.achievementCount },
}
LeaderboardService.ServerRefresh = 15

local cache = { server = {}, global = {}, updatedAt = 0 }
local stores = {}
local lastWrite = {} -- [userId][board] = { value, at }
local names = {} -- [userId] = nome

local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.DisplayName
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = ok and name or ("Jogador " .. userId)
	return names[userId]
end

function LeaderboardService.computeServer()
	for _, board in ipairs(LeaderboardService.Boards) do
		local rows = {}
		for _, player in ipairs(PlayerDataService.loadedPlayers()) do
			local profile = PlayerDataService.getProfile(player)
			table.insert(rows, { name = player.DisplayName, value = board.metric(profile), userId = player.UserId })
		end
		table.sort(rows, function(a, b)
			return a.value > b.value
		end)
		while #rows > EconomyConfig.LeaderboardSize do
			table.remove(rows)
		end
		cache.server[board.id] = rows
	end
end

local function writeGlobal(player, profile, force)
	if PlayerDataService.memoryMode then
		return
	end
	local now = os.clock()
	local byBoard = lastWrite[player.UserId] or {}
	lastWrite[player.UserId] = byBoard
	for _, board in ipairs(LeaderboardService.Boards) do
		local value = math.floor(board.metric(profile))
		local last = byBoard[board.id]
		if value > 0 and (not last or (last.value ~= value and (force or now - last.at >= EconomyConfig.LeaderboardWriteInterval))) then
			byBoard[board.id] = { value = value, at = now }
			local ok, err = pcall(function()
				stores[board.id]:SetAsync(tostring(player.UserId), value)
			end)
			if not ok then
				warn("[MYSTERY MACHINE] ranking global: falha ao gravar " .. board.id .. ": " .. tostring(err))
			end
		end
	end
end

function LeaderboardService.refreshGlobal()
	if PlayerDataService.memoryMode then
		return
	end
	for _, board in ipairs(LeaderboardService.Boards) do
		local ok, page = pcall(function()
			return stores[board.id]:GetSortedAsync(false, EconomyConfig.LeaderboardSize):GetCurrentPage()
		end)
		if ok then
			local rows = {}
			for _, entry in ipairs(page) do
				local userId = tonumber(entry.key)
				table.insert(rows, { name = userId and nameOf(userId) or "?", value = entry.value, userId = userId })
			end
			cache.global[board.id] = rows
		end
	end
	cache.updatedAt = os.clock()
end

local function drawBoard()
	local frame = MapService.rankingBoard
	if not frame then
		return
	end
	local old = frame:FindFirstChild("Columns")
	if old then
		old:Destroy()
	end
	local columns = Instance.new("Frame")
	columns.Name = "Columns"
	columns.BackgroundTransparency = 1
	columns.Position = UDim2.new(0, 0, 0.15, 0)
	columns.Size = UDim2.new(1, 0, 0.85, 0)
	columns.Parent = frame
	for i, board in ipairs(LeaderboardService.Boards) do
		local rows = cache.global[board.id]
		if not rows or #rows == 0 then
			rows = cache.server[board.id] or {}
		end
		local col = Instance.new("TextLabel")
		col.BackgroundTransparency = 1
		col.Position = UDim2.new((i - 1) / 4, 6, 0, 0)
		col.Size = UDim2.new(0.25, -12, 1, 0)
		col.Font = Enum.Font.GothamBold
		col.TextScaled = true
		col.TextXAlignment = Enum.TextXAlignment.Left
		col.TextYAlignment = Enum.TextYAlignment.Top
		col.TextColor3 = Color3.fromRGB(255, 255, 255)
		local lines = { board.name }
		for r = 1, math.min(5, #rows) do
			table.insert(lines, r .. ". " .. rows[r].name .. "  " .. Format.short(rows[r].value))
		end
		if #rows == 0 then
			table.insert(lines, "—")
		end
		col.Text = table.concat(lines, "\n")
		col.Parent = columns
	end
end

function LeaderboardService.get()
	return cache
end

function LeaderboardService.broadcast()
	Remotes.event("LeaderboardUpdated"):FireAllClients(cache)
	drawBoard()
end

function LeaderboardService.start()
	for _, board in ipairs(LeaderboardService.Boards) do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore("MysteryMachine_LB_" .. board.id .. "_v1")
		end)
		stores[board.id] = ok and store or nil
	end
	Remotes.handle("ProgressAction", "leaderboard", "progress", function()
		return { ok = true, data = cache }
	end)
	PlayerDataService.onLoaded(function(player)
		Remotes.event("LeaderboardUpdated"):FireClient(player, cache)
	end)
	PlayerDataService.onLeaving(function(player, profile)
		writeGlobal(player, profile, true)
		lastWrite[player.UserId] = nil
	end)
	task.spawn(function()
		local sinceGlobal = math.huge
		while true do
			LeaderboardService.computeServer()
			for _, player in ipairs(PlayerDataService.loadedPlayers()) do
				local profile = PlayerDataService.getProfile(player)
				if profile then
					writeGlobal(player, profile, false)
				end
			end
			if sinceGlobal >= EconomyConfig.LeaderboardRefresh then
				sinceGlobal = 0
				LeaderboardService.refreshGlobal()
			end
			LeaderboardService.broadcast()
			sinceGlobal = sinceGlobal + task.wait(LeaderboardService.ServerRefresh)
		end
	end)
end

return LeaderboardService
