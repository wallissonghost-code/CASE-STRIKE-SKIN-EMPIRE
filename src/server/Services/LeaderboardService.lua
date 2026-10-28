-- LeaderboardService: rankings globais (OrderedDataStore) com cache e atualização periódica,
-- além de um ranking ao vivo do servidor. Os clientes leem sempre o cache (sem consultas por pedido).
-- Os valores vêm de LeaderboardStats, que conta cada skin uma vez e não inclui renda pendente.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local LeaderboardStats = require(Shared.Logic.LeaderboardStats)
local Format = require(Shared.Util.Format)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local LeaderboardService = {}

local WRITE_INTERVAL = 120
local READ_INTERVAL = 150
local TOP_N = 20

local stores = {}
local lastWritten = {} -- [userId] = { [boardId] = valor }
local cache = { updatedAt = 0, boards = {} }
local nameCache = {}
local enabled = true

local function nameFor(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		nameCache[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	name = ok and name or ("Jogador " .. tostring(userId))
	nameCache[userId] = name
	return name
end

local function writePlayer(player)
	local profile = PlayerDataService.getProfile(player)
	if not profile then
		return
	end
	local stats = LeaderboardStats.compute(profile)
	local last = lastWritten[player.UserId] or {}
	for _, board in ipairs(LeaderboardStats.Boards) do
		local value = math.floor(stats[board.id] or 0)
		if last[board.id] ~= value then
			local ok, err = pcall(function()
				stores[board.id]:SetAsync(tostring(player.UserId), value)
			end)
			if ok then
				last[board.id] = value
			else
				warn("[Leaderboard] falha ao gravar " .. board.id .. ": " .. tostring(err))
			end
		end
	end
	lastWritten[player.UserId] = last
end

local function readBoards()
	local boards = {}
	for _, board in ipairs(LeaderboardStats.Boards) do
		local ok, pages = pcall(function()
			return stores[board.id]:GetSortedAsync(false, TOP_N)
		end)
		local rows = {}
		if ok then
			for rank, entry in ipairs(pages:GetCurrentPage()) do
				local userId = tonumber(entry.key)
				table.insert(rows, { rank = rank, name = userId and nameFor(userId) or entry.key, value = entry.value })
			end
		else
			warn("[Leaderboard] falha ao ler " .. board.id .. ": " .. tostring(pages))
			rows = (cache.boards[board.id] or {}) -- mantém o cache anterior
		end
		boards[board.id] = rows
	end
	cache = { updatedAt = DateTime.now().UnixTimestamp, boards = boards }
end

local function serverBoard()
	local rows = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = PlayerDataService.getProfile(player)
		if profile then
			local s = LeaderboardStats.compute(profile)
			s.name = player.DisplayName
			table.insert(rows, s)
		end
	end
	return rows
end

-- painel físico do lobby: top 10 de patrimônio (global em cache; sem DataStore, o do servidor)
local function updateBoard()
	local lobby = workspace:FindFirstChild("Lobby")
	local board = lobby and lobby:FindFirstChild("RankingBoard")
	local label = board and board:FindFirstChild("RankingGui") and board.RankingGui:FindFirstChild("Rows")
	if not label then
		return
	end
	local rows = {}
	local global = cache.boards.netWorth
	if enabled and global and #global > 0 then
		for _, r in ipairs(global) do
			table.insert(rows, { name = r.name, value = r.value })
		end
	else
		for _, s in ipairs(serverBoard()) do
			table.insert(rows, { name = s.name, value = s.netWorth })
		end
		table.sort(rows, function(a, b)
			return a.value > b.value
		end)
	end
	local lines = { enabled and "🏆 PATRIMÔNIO — GLOBAL" or "🏆 PATRIMÔNIO — SERVIDOR" }
	for i = 1, math.min(10, #rows) do
		table.insert(lines, "#" .. i .. "  " .. tostring(rows[i].name) .. "  —  ₵ " .. Format.short(rows[i].value))
	end
	if #rows == 0 then
		table.insert(lines, "Ainda sem dados")
	end
	label.Text = table.concat(lines, "\n")
end

function LeaderboardService.init()
	if PlayerDataService.isMemoryMode() then
		enabled = false
		return
	end
	for _, board in ipairs(LeaderboardStats.Boards) do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore("CS_LB_" .. board.id .. "_v1")
		end)
		if not ok then
			enabled = false
			warn("[Leaderboard] rankings globais desativados: " .. tostring(store))
			return
		end
		stores[board.id] = store
	end
end

function LeaderboardService.start()
	Remotes.on("LeaderboardRequest", "get", "Leaderboard", function()
		local boards = {}
		for _, b in ipairs(LeaderboardStats.Boards) do
			table.insert(boards, { id = b.id, displayName = b.displayName })
		end
		return {
			ok = true,
			data = {
				globalEnabled = enabled,
				updatedAt = cache.updatedAt,
				boards = boards,
				global = cache.boards,
				server = serverBoard(),
			},
		}
	end)

	task.spawn(function()
		while true do
			task.wait(15)
			updateBoard()
		end
	end)

	if not enabled then
		return
	end
	task.spawn(function()
		task.wait(20)
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				writePlayer(player)
				task.wait(0.5)
			end
			task.wait(WRITE_INTERVAL)
		end
	end)
	task.spawn(function()
		task.wait(30)
		while true do
			readBoards()
			task.wait(READ_INTERVAL)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		writePlayer(player)
		lastWritten[player.UserId] = nil
	end)
end

return LeaderboardService
