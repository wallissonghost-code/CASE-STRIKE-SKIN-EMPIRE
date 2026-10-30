-- Livro de coleções (não confundir com o CollectionService de tags do Roblox):
-- recompensas por completar partes da coleção, títulos cosméticos e o título acima da cabeça.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionDefinitions = require(Shared.MissionDefinitions)
local ProfileOps = require(Shared.Logic.ProfileOps)
local Remotes = require(script.Parent.Parent.Core.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CollectionBook = {}

local shownTitle = {} -- [player] = id do título aplicado ao personagem

local function applyTitle(player, profile)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local titleId = profile and profile.title or ""
	local tag = head:FindFirstChild("TitleTag")
	if shownTitle[player] == titleId and (titleId == "") == (tag == nil) then
		return
	end
	shownTitle[player] = titleId
	if tag then
		tag:Destroy()
	end
	local def = MissionDefinitions.Titles[titleId]
	if not def then
		return
	end
	tag = Instance.new("BillboardGui")
	tag.Name = "TitleTag"
	tag.Size = UDim2.new(0, 220, 0, 32)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 60
	tag.AlwaysOnTop = false
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, 0, 1, 0)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = "« " .. def.name .. " »"
	text.TextColor3 = def.color
	text.TextStrokeTransparency = 0.3
	text.Parent = tag
	tag.Parent = head
end

function CollectionBook.start()
	Remotes.handle("ProgressAction", "claimSet", "progress", function(_, profile, payload)
		return ProfileOps.claimSet(profile, payload.setId)
	end)
	Remotes.handle("ProgressAction", "setTitle", "progress", function(_, profile, payload)
		return ProfileOps.setTitle(profile, payload.titleId)
	end)
	PlayerDataService.onLoaded(function(player, profile)
		player.CharacterAdded:Connect(function()
			shownTitle[player] = nil
			task.wait(0.5)
			applyTitle(player, PlayerDataService.getProfile(player))
		end)
		applyTitle(player, profile)
	end)
	PlayerDataService.onChanged(applyTitle)
	PlayerDataService.onLeaving(function(player)
		shownTitle[player] = nil
	end)
end

return CollectionBook
