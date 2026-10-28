-- LobbyController: interação com o lobby (atalhos dos prédios, vitrine giratória de caixas)
-- e o painel da Batalha, bloqueado com "EM BREVE".

local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local FeatureFlags = require(Shared.Config.FeatureFlags)

local UI = require(script.Parent.UIController)

local Lobby = {}

local function buildBattle()
	local p = UI.createPanel("⚔️ Batalha", 620, 380)
	UI.text({
		Text = "<b>" .. FeatureFlags.LockedLabel .. "</b>\n\nPvP, combate contra monstros e chefes estão reservados para atualizações futuras.\nNesta versão, as skins são apenas cosméticas e não causam dano.",
		Font = UI.Fonts.body,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = p.content,
	})
	return { frame = p.frame }
end

function Lobby.init()
	UI.register("Battle", buildBattle)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local panel = prompt:GetAttribute("OpenPanel")
		if type(panel) ~= "string" then
			return
		end
		local caseId = prompt:GetAttribute("CaseId")
		if caseId then
			UI.open("CaseWindow", { caseId = caseId })
		else
			UI.open(panel)
		end
	end)

	-- vitrine: gira as caixas da praça (apenas no cliente, sem custo no servidor)
	local spinners = {}
	local function scan()
		spinners = {}
		local lobby = workspace:FindFirstChild("Lobby")
		if not lobby then
			return
		end
		for _, m in ipairs(lobby:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("Spin") then
				table.insert(spinners, { model = m, base = m:GetPivot() })
			end
		end
	end
	task.spawn(function()
		workspace:WaitForChild("Lobby", 30)
		task.wait(2)
		scan()
	end)
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t = t + dt
		for _, s in ipairs(spinners) do
			if s.model.Parent then
				s.model:PivotTo(s.base * CFrame.new(0, math.sin(t * 1.5) * 0.3, 0) * CFrame.Angles(0, t * 0.8, 0))
			end
		end
	end)
end

return Lobby
