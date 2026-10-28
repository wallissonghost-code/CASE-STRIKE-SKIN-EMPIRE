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

	-- vitrine e showroom: gira caixas e skins expostas (apenas no cliente, sem custo no servidor).
	-- Acompanha modelos que entram/saem (as vitrines mudam quando os jogadores expõem skins).
	local spinners = {}
	local function track(m)
		if m:IsA("Model") and m:GetAttribute("Spin") and not spinners[m] then
			spinners[m] = { base = m:GetPivot(), phase = math.random() * 6 }
		end
	end
	task.spawn(function()
		local lobby = workspace:WaitForChild("Lobby", 30)
		if not lobby then
			return
		end
		for _, d in ipairs(lobby:GetDescendants()) do
			track(d)
		end
		lobby.DescendantAdded:Connect(function(d)
			task.defer(track, d)
		end)
	end)
	local t = 0
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		t = t + dt
		acc = acc + dt
		if acc < 1 / 30 then
			return -- 30 atualizações por segundo bastam para a decoração (economiza no celular)
		end
		acc = 0
		for m, s in pairs(spinners) do
			if m.Parent then
				m:PivotTo(s.base * CFrame.new(0, math.sin(t * 1.5 + s.phase) * 0.3, 0) * CFrame.Angles(0, t * 0.8 + s.phase, 0))
			else
				spinners[m] = nil
			end
		end
	end)
end

return Lobby
