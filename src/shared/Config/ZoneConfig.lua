-- ZoneConfig: zonas do mapa. Cada zona é desbloqueada uma vez com créditos do jogo e dá
-- sorte extra ENQUANTO o jogador estiver dentro dela. A posição é verificada pelo SERVIDOR
-- (o cliente só desenha as barreiras das zonas ainda bloqueadas).
--
-- area: caixa alinhada aos eixos { center = {x, z}, size = {x, z} } no chão do lobby.

local ZoneConfig = {}

ZoneConfig.Zones = {
	{
		id = "zone1",
		name = "Zona 1 — Praça",
		order = 1,
		cost = 0,
		requiredLevel = 1,
		luck = 0,
		color = { 120, 200, 120 },
		-- a zona 1 é o restante do mapa (não precisa de área)
	},
	{
		id = "zone2",
		name = "Zona 2 — Campos Floridos",
		order = 2,
		cost = 5000,
		requiredLevel = 5,
		luck = 0.05,
		color = { 255, 200, 90 },
		area = { center = { 235, 0 }, size = { 110, 140 } },
	},
	{
		id = "zone3",
		name = "Zona 3 — Vale Assombrado",
		order = 3,
		cost = 20000,
		requiredLevel = 12,
		luck = 0.05,
		color = { 170, 90, 240 },
		area = { center = { -235, 0 }, size = { 110, 140 } },
		requires = "zone2",
	},
	{
		id = "zone4",
		name = "Zona 4 — Cume Cristalino",
		order = 4,
		cost = 75000,
		requiredLevel = 25,
		luck = 0.05,
		color = { 90, 210, 255 },
		area = { center = { 0, -235 }, size = { 160, 110 } },
		requires = "zone3",
	},
}

ZoneConfig.ById = {}
for _, z in ipairs(ZoneConfig.Zones) do
	ZoneConfig.ById[z.id] = z
end

-- zona em que uma posição (x, z) está; "zone1" quando fora de todas as áreas
function ZoneConfig.zoneAt(x, z)
	for _, zone in ipairs(ZoneConfig.Zones) do
		local a = zone.area
		if a then
			if math.abs(x - a.center[1]) <= a.size[1] / 2 and math.abs(z - a.center[2]) <= a.size[2] / 2 then
				return zone.id
			end
		end
	end
	return "zone1"
end

return ZoneConfig
