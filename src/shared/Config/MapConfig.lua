-- MapConfig: geometria do mapa (usada pelo servidor para construir e validar posições,
-- e pelo cliente para efeitos locais). Coordenadas em studs; y = 0 é o chão.

local MapConfig = {}

MapConfig.GroundSize = 440
MapConfig.Fence = 205 -- cerca em ±205

-- esteira: atravessa a praça de oeste para leste
MapConfig.Conveyor = {
	startX = -72,
	endX = 72,
	z = 0,
	y = 2.2, -- altura das criaturas sobre a esteira
	width = 10,
}

-- quiosques de ovos e loja de poções
MapConfig.EggKiosks = {
	basico = { x = -26, z = -26 },
	raro = { x = 0, z = -30 },
	lendario = { x = 26, z = -26 },
}
MapConfig.PotionShop = { x = 26, z = 28 }
MapConfig.EventBoard = { x = -26, z = 28 }

-- 6 bases: três ao norte (entrada virada para o sul) e três ao sul (entrada para o norte)
MapConfig.BaseSize = 72
MapConfig.Bases = {
	{ x = -120, z = -122, facing = 1 },
	{ x = 0, z = -122, facing = 1 },
	{ x = 120, z = -122, facing = 1 },
	{ x = -120, z = 122, facing = -1 },
	{ x = 0, z = 122, facing = -1 },
	{ x = 120, z = 122, facing = -1 },
}
MapConfig.BaseColors = {
	{ 90, 220, 110 },
	{ 80, 170, 255 },
	{ 255, 170, 60 },
	{ 230, 90, 200 },
	{ 255, 220, 70 },
	{ 150, 110, 255 },
}

-- coordenadas locais da base: +lz aponta para a entrada (para a praça)
MapConfig.PadColumns = 5
MapConfig.PadSpacing = 12
MapConfig.PadRowsZ = { -24, -12, 0, 12 } -- do fundo para a frente
MapConfig.Terminal = {
	collect = { lx = 14, lz = 28 },
	shield = { lx = -14, lz = 28 },
	spawn = { lx = 0, lz = 22 },
}

function MapConfig.toWorld(baseIndex, lx, lz)
	local b = MapConfig.Bases[baseIndex]
	return b.x + lx * b.facing, b.z + lz * b.facing
end

-- posição (x, z) do pedestal i (1..20)
function MapConfig.padPosition(baseIndex, i)
	local col = (i - 1) % MapConfig.PadColumns
	local row = math.floor((i - 1) / MapConfig.PadColumns) + 1
	local lx = (col - (MapConfig.PadColumns - 1) / 2) * MapConfig.PadSpacing
	local lz = MapConfig.PadRowsZ[row] or 0
	return MapConfig.toWorld(baseIndex, lx, lz)
end

-- índice da base em que o ponto (x, z) está, ou nil
function MapConfig.baseAt(x, z)
	local half = MapConfig.BaseSize / 2
	for i, b in ipairs(MapConfig.Bases) do
		if math.abs(x - b.x) <= half and math.abs(z - b.z) <= half then
			return i
		end
	end
	return nil
end

-- quem rouba entrega a criatura ao entrar na PRÓPRIA base
function MapConfig.inDelivery(baseIndex, x, z)
	return baseIndex ~= nil and MapConfig.baseAt(x, z) == baseIndex
end

return MapConfig
