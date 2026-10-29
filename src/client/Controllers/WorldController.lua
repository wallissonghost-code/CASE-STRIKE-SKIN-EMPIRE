-- WorldController: liga o mundo 3D à interface.
-- * Botões de proximidade (E) que abrem painéis (ovos, poções).
-- * Esconde "Roubar" nas próprias criaturas e os terminais das bases dos outros.
-- * Anima as criaturas Arco-íris (só visual, no cliente).
-- * Avisos do servidor: roubo em andamento (faixa vermelha), defesa, eventos, compras raras.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local UI = require(script.Parent.UIController)
local Net = require(script.Parent.Parent.Util.Net)
local Store = require(script.Parent.Parent.Util.Store)

local World = {}

local player = Players.LocalPlayer
local rainbow = {} -- [model] = true
local alertBanner

local function setupPrompt(p)
	local function apply()
		local owner = p:GetAttribute("OwnerUserId")
		if p:GetAttribute("Steal") then
			p.Enabled = owner ~= player.UserId
		elseif p:GetAttribute("OwnerOnly") then
			p.Enabled = owner == player.UserId
		end
	end
	apply()
	p:GetAttributeChangedSignal("OwnerUserId"):Connect(apply)
end

local function watch(inst)
	if inst:IsA("ProximityPrompt") then
		setupPrompt(inst)
	elseif inst:IsA("Model") and inst:GetAttribute("Rainbow") then
		rainbow[inst] = true
	end
end

local function showAlert(text)
	alertBanner.Text = text
	alertBanner.Visible = true
	local token = {}
	World._alertToken = token
	task.delay(5, function()
		if World._alertToken == token then
			alertBanner.Visible = false
		end
	end)
end

local function onNotify(data)
	if type(data) ~= "table" or type(data.text) ~= "string" then
		return
	end
	if data.kind == "theft" then
		showAlert(data.text)
		UI.toast(data.text, "error")
	elseif data.kind == "error" then
		UI.toast(data.text, "error")
	elseif data.kind == "good" then
		UI.toast(data.text, "good")
	elseif data.kind == "rare" or data.kind == "event" or data.kind == "carry" then
		UI.toast(data.text, "rare")
	else
		UI.toast(data.text)
	end
end

function World.init()
	alertBanner = UI.text({
		Name = "TheftAlert",
		Text = "",
		Font = UI.Fonts.title,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0.05,
		BackgroundColor3 = Color3.fromRGB(200, 30, 45),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 164),
		Size = UDim2.fromOffset(720, 56),
		Visible = false,
		Parent = UI.layers.Toast,
	})
	UI.corner(alertBanner, 12)

	Net.on("Notify", onNotify)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local panel = prompt:GetAttribute("Panel")
		if panel then
			UI.open(panel, { eggId = prompt:GetAttribute("EggId") })
		end
	end)

	local world = workspace:FindFirstChild("MutantWorld") or workspace:WaitForChild("MutantWorld")
	for _, d in ipairs(world:GetDescendants()) do
		watch(d)
	end
	world.DescendantAdded:Connect(watch)

	-- cores do Arco-íris (10 vezes por segundo, desligado com "Reduzir efeitos")
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc = acc + dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local v = Store.view
		if v and v.settings and v.settings.reduceEffects then
			return
		end
		local h = (os.clock() * 0.25) % 1
		for model in pairs(rainbow) do
			if not model.Parent then
				rainbow[model] = nil
			else
				for _, part in ipairs(model:GetChildren()) do
					if part:IsA("BasePart") and part.Name ~= "EyeWhite" and part.Name ~= "Pupil" then
						part.Color = Color3.fromHSV(h, 0.75, 1)
					end
				end
			end
		end
	end)
end

return World
