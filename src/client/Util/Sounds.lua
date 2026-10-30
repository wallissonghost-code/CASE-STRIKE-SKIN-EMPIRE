-- Efeitos sonoros. Usa apenas sons que já vêm com o Roblox (rbxasset://), sem IDs inventados.
-- Para trocar por sons próprios, substitua os caminhos por "rbxassetid://<id do seu áudio>".

local SoundService = game:GetService("SoundService")
local Store = require(script.Parent.Store)

local Sounds = {}

Sounds.Library = {
	click = { id = "rbxasset://sounds/button.wav", volume = 0.4 },
	spin = { id = "rbxasset://sounds/clickfast.wav", volume = 0.35 },
	reveal = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6 },
	coins = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, speed = 1.4 },
	legendary = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.9, speed = 0.7 },
}

local cache = {}

local function get(name)
	if cache[name] then
		return cache[name]
	end
	local def = Sounds.Library[name]
	if not def then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "SFX_" .. name
	s.SoundId = def.id
	s.Volume = def.volume or 0.5
	s.PlaybackSpeed = def.speed or 1
	s.Parent = SoundService
	cache[name] = s
	return s
end

function Sounds.play(name)
	if Store.setting("sound") == false then
		return
	end
	local s = get(name)
	if s then
		SoundService:PlayLocalSound(s)
	end
end

-- som 3D preso a uma peça (máquina); retorna a instância para poder parar
function Sounds.playAt(name, part)
	if Store.setting("sound") == false or not part then
		return nil
	end
	local def = Sounds.Library[name]
	local s = Instance.new("Sound")
	s.SoundId = def.id
	s.Volume = def.volume or 0.5
	s.PlaybackSpeed = def.speed or 1
	s.RollOffMaxDistance = 60
	s.Parent = part
	s:Play()
	task.delay(6, function()
		s:Destroy()
	end)
	return s
end

return Sounds
