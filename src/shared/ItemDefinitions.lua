-- Os 20 objetos colecionáveis. Para adicionar um objeto: crie a entrada aqui (id único e estável,
-- nunca reutilize um id antigo), adicione o modelo em Visual/ItemModels e coloque-o no pool de uma
-- máquina em MachineDefinitions.
-- value: moedas recebidas na venda e valor para o ranking de coleção.

local ItemDefinitions = {}

ItemDefinitions.List = {
	-- Máquina Comum
	{ id = "cup", name = "Copo", rarity = "common", value = 10, machine = "common" },
	{ id = "ball", name = "Bola", rarity = "common", value = 14, machine = "common" },
	{ id = "toy_car", name = "Carrinho de Brinquedo", rarity = "uncommon", value = 30, machine = "common" },
	{ id = "teddy", name = "Urso de Pelúcia", rarity = "rare", value = 70, machine = "common" },
	{ id = "headphones", name = "Fone de Ouvido", rarity = "epic", value = 180, machine = "common" },
	-- Máquina Neon
	{ id = "watch", name = "Relógio Digital", rarity = "common", value = 60, machine = "neon" },
	{ id = "gamepad", name = "Controle de Videogame", rarity = "uncommon", value = 110, machine = "neon" },
	{ id = "phone", name = "Celular", rarity = "rare", value = 240, machine = "neon" },
	{ id = "drone", name = "Drone", rarity = "epic", value = 500, machine = "neon" },
	{ id = "handheld", name = "Console Portátil", rarity = "legendary", value = 1200, machine = "neon" },
	-- Máquina Dourada
	{ id = "robot", name = "Robô de Brinquedo", rarity = "uncommon", value = 320, machine = "golden" },
	{ id = "scooter", name = "Patinete Futurista", rarity = "rare", value = 600, machine = "golden" },
	{ id = "rocket", name = "Mini Foguete", rarity = "rare", value = 900, machine = "golden" },
	{ id = "diamond", name = "Diamante", rarity = "epic", value = 2000, machine = "golden" },
	{ id = "crown", name = "Coroa Dourada", rarity = "legendary", value = 5000, machine = "golden" },
	-- Máquina Misteriosa
	{ id = "crystal_dragon", name = "Dragão de Cristal", rarity = "rare", value = 1500, machine = "mystery" },
	{ id = "cosmic_cube", name = "Cubo Cósmico", rarity = "epic", value = 2600, machine = "mystery" },
	{ id = "ancient_relic", name = "Relíquia Antiga", rarity = "epic", value = 4200, machine = "mystery" },
	{ id = "galactic_star", name = "Estrela Galáctica", rarity = "legendary", value = 7500, machine = "mystery" },
	{ id = "secret_artifact", name = "Artefato Secreto", rarity = "secret", value = 40000, machine = "mystery" },
}

ItemDefinitions.ById = {}
for index, item in ipairs(ItemDefinitions.List) do
	item.index = index
	ItemDefinitions.ById[item.id] = item
end

function ItemDefinitions.get(id)
	if type(id) ~= "string" then
		return nil
	end
	return ItemDefinitions.ById[id]
end

function ItemDefinitions.count()
	return #ItemDefinitions.List
end

return ItemDefinitions
