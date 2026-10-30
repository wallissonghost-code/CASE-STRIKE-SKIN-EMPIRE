-- Presente diário gratuito e avisos de recompensas (subida de nível, títulos).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionDefinitions = require(Shared.MissionDefinitions)
local MachineDefinitions = require(Shared.MachineDefinitions)
local ProfileOps = require(Shared.Logic.ProfileOps)
local TimeUtil = require(Shared.Util.TimeUtil)
local Format = require(Shared.Util.Format)
local Remotes = require(script.Parent.Parent.Core.Remotes)

local RewardService = {}

-- chamado depois de toda operação bem-sucedida
function RewardService.announce(player, result)
	if type(result.levels) == "table" then
		for _, level in ipairs(result.levels) do
			local text = "⭐ Nível " .. level .. "!"
			for _, m in ipairs(MachineDefinitions.List) do
				if m.level == level then
					text = text .. " " .. m.name .. " desbloqueada!"
				end
			end
			Remotes.notify(player, text, "level")
		end
		if (result.levelCoins or 0) > 0 then
			Remotes.notify(player, "🎁 Recompensa de nível: +" .. Format.int(result.levelCoins) .. " Coins", "coins")
		end
	end
	if result.title and MissionDefinitions.Titles[result.title] then
		Remotes.notify(player, "🏷️ Novo título: " .. MissionDefinitions.Titles[result.title].name, "level")
	end
end

function RewardService.start()
	Remotes.handle("ProgressAction", "claimGift", "progress", function(_, profile)
		return ProfileOps.claimGift(profile, TimeUtil.now())
	end)
	Remotes.onSuccess(RewardService.announce)
end

return RewardService
