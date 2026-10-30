-- Máquinas misteriosas. Preços, níveis e chances são configuráveis aqui.
-- `pool`: chance de cada objeto em PORCENTAGEM. A soma de cada pool deve dar 100
-- (verificado nos testes). A interface mostra exatamente estes números antes de cada abertura,
-- e o servidor sorteia com eles: não existe nenhum modificador escondido de probabilidade.

local MachineDefinitions = {}

MachineDefinitions.List = {
	{
		id = "common",
		name = "Máquina Comum",
		price = 25,
		level = 1,
		bodyColor = Color3.fromRGB(80, 170, 255),
		accentColor = Color3.fromRGB(255, 255, 255),
		lightColor = Color3.fromRGB(120, 220, 255),
		pool = {
			{ item = "cup", chance = 45 },
			{ item = "ball", chance = 30 },
			{ item = "toy_car", chance = 15 },
			{ item = "teddy", chance = 8 },
			{ item = "headphones", chance = 2 },
		},
	},
	{
		id = "neon",
		name = "Máquina Neon",
		price = 150,
		level = 5,
		bodyColor = Color3.fromRGB(40, 30, 70),
		accentColor = Color3.fromRGB(255, 70, 220),
		lightColor = Color3.fromRGB(0, 255, 210),
		pool = {
			{ item = "watch", chance = 50 },
			{ item = "gamepad", chance = 28 },
			{ item = "phone", chance = 15 },
			{ item = "drone", chance = 6 },
			{ item = "handheld", chance = 1 },
		},
	},
	{
		id = "golden",
		name = "Máquina Dourada",
		price = 750,
		level = 15,
		bodyColor = Color3.fromRGB(230, 175, 40),
		accentColor = Color3.fromRGB(255, 245, 200),
		lightColor = Color3.fromRGB(255, 220, 90),
		pool = {
			{ item = "robot", chance = 48 },
			{ item = "scooter", chance = 28 },
			{ item = "rocket", chance = 15 },
			{ item = "diamond", chance = 7.5 },
			{ item = "crown", chance = 1.5 },
		},
	},
	{
		id = "mystery",
		name = "Máquina Misteriosa",
		price = 3000,
		level = 30,
		bodyColor = Color3.fromRGB(25, 20, 35),
		accentColor = Color3.fromRGB(150, 60, 255),
		lightColor = Color3.fromRGB(255, 60, 80),
		pool = {
			{ item = "crystal_dragon", chance = 50 },
			{ item = "cosmic_cube", chance = 30 },
			{ item = "ancient_relic", chance = 14 },
			{ item = "galactic_star", chance = 5.5 },
			{ item = "secret_artifact", chance = 0.5 },
		},
	},
}

-- distância máxima (studs) entre o jogador e o botão da máquina para usá-la
MachineDefinitions.UseRadius = 16

MachineDefinitions.ById = {}
for index, machine in ipairs(MachineDefinitions.List) do
	machine.index = index
	MachineDefinitions.ById[machine.id] = machine
end

function MachineDefinitions.get(id)
	if type(id) ~= "string" then
		return nil
	end
	return MachineDefinitions.ById[id]
end

function MachineDefinitions.cheapestPrice()
	local best = math.huge
	for _, m in ipairs(MachineDefinitions.List) do
		best = math.min(best, m.price)
	end
	return best
end

return MachineDefinitions
