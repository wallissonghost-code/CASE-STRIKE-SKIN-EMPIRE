-- CaseCatalog: FONTE ÚNICA das caixas e de suas coleções (dados puros).
-- Para adicionar uma nova coleção/caixa basta acrescentar uma entrada aqui:
-- SkinDefinitions, CaseDefinitions, o Índice, a loja e a validação de RNG leem esta lista
-- automaticamente, sem mudanças no código de abertura.
--
-- Campos:
--   id, name, collection (nome da coleção), price, requiredLevel, theme
--   color/trim (RGB do modelo da caixa), palette (3 cores RGB das skins)
--   rarityWeights (opcional): pesos por raridade SÓ desta caixa; sem ele usa RarityConfig.BaseWeights
--   eventId (opcional): caixa disponível apenas durante esse evento
--   section: "level" (Caixas de Nível — cada uma forma uma coleção), "special" (Caixas Especiais)
--            ou "limited" (Estoque Limitado: stockPerDay aberturas por jogador por dia UTC)
--   skins: lista { raridade, arma, acabamento } (ordem define o id: <caixa>_<NN>) — só caixas de coleção
--   pool: (caixas especiais/limitadas) seleciona skins JÁ EXISTENTES por filtro
--         { category, collections = {...}, minTier, maxTier }; sem price, o preço é calculado
--         pelo valor esperado do sorteio (EV / TargetExpectedValue), sem desconto artificial.

local CaseCatalog = {}

CaseCatalog.List = {
	{
		id = "starter", name = "Caixa Starter", collection = "Coleção Recruta", price = 10, section = "level", requiredLevel = 1,
		theme = "Primeiros passos do colecionador",
		color = { 90, 150, 110 }, trim = { 240, 240, 240 },
		palette = { { 110, 170, 120 }, { 235, 235, 225 }, { 60, 90, 70 } },
		skins = {
			{ "Common", "VespaP9", "Recruta" },
			{ "Common", "HornetMX", "Treino" },
			{ "Uncommon", "RookR1", "Cadete" },
			{ "Uncommon", "WaspK7", "Faixa Branca" },
			{ "Rare", "TalonAR", "Primeira Patente" },
		},
	},
	{
		id = "urban", name = "Caixa Urban", collection = "Coleção Concreto", price = 25, section = "level", requiredLevel = 1,
		theme = "Concreto e grafite da cidade",
		color = { 130, 135, 145 }, trim = { 230, 110, 60 },
		palette = { { 120, 124, 130 }, { 70, 72, 78 }, { 200, 90, 60 } },
		skins = {
			{ "Common", "VespaP9", "Concreto" },
			{ "Uncommon", "HornetMX", "Grafite Urbano" },
			{ "Uncommon", "Mako45", "Pichação" },
			{ "Rare", "BastionR7", "Metrô Noturno" },
			{ "Epic", "GaleC4", "Arranha-Céu" },
		},
	},
	{
		id = "tactical", name = "Caixa Tactical", collection = "Coleção Operação", price = 75, section = "level", requiredLevel = 3,
		theme = "Equipamento militar e camuflagem",
		color = { 95, 110, 70 }, trim = { 200, 180, 120 },
		palette = { { 96, 110, 70 }, { 170, 150, 110 }, { 60, 66, 50 } },
		skins = {
			{ "Common", "RookR1", "Oliva" },
			{ "Uncommon", "WaspK7", "Areia" },
			{ "Rare", "Kestrel50", "Camuflagem Digital" },
			{ "Rare", "BastionR7", "Ranger" },
			{ "Epic", "LongbowSR", "Atirador Fantasma" },
		},
	},
	{
		id = "neon", name = "Caixa Neon", collection = "Coleção Fliperama", price = 150, section = "level", requiredLevel = 5,
		theme = "Fliperama, synthwave e luz",
		color = { 60, 25, 100 }, trim = { 255, 70, 200 },
		palette = { { 255, 70, 200 }, { 40, 230, 255 }, { 30, 20, 60 } },
		skins = {
			{ "Common", "Mako45", "Pixel Rosa" },
			{ "Uncommon", "RatchetV", "Fliperama" },
			{ "Rare", "TalonAR", "Holograma" },
			{ "Epic", "HornetMX", "Pulso Ultravioleta" },
			{ "Legendary", "LiraBorboleta", "Prisma" },
		},
	},
	{
		id = "shadow", name = "Caixa Shadow", collection = "Coleção Eclipse", price = 300, section = "level", requiredLevel = 8,
		theme = "Fumaça, eclipse e trevas",
		color = { 30, 28, 40 }, trim = { 140, 90, 220 },
		palette = { { 30, 28, 40 }, { 90, 60, 140 }, { 15, 15, 20 } },
		skins = {
			{ "Uncommon", "WaspK7", "Eclipse Fosco" },
			{ "Rare", "Mako45", "Abismo" },
			{ "Rare", "TalonAR", "Meia-Noite" },
			{ "Epic", "Kestrel50", "Espectro" },
			{ "Legendary", "CorvoFaca", "Lua Nova" },
		},
	},
	{
		id = "chrome", name = "Caixa Chrome", collection = "Coleção Cromo", price = 600, section = "level", requiredLevel = 12,
		theme = "Metal polido, espelhos e turbinas",
		color = { 180, 190, 205 }, trim = { 90, 200, 255 },
		palette = { { 200, 205, 215 }, { 120, 130, 145 }, { 90, 200, 255 } },
		skins = {
			{ "Uncommon", "VespaP9", "Espelho" },
			{ "Rare", "RatchetV", "Cromo Polido" },
			{ "Epic", "GaleC4", "Aço Líquido" },
			{ "Epic", "BastionR7", "Turbina" },
			{ "Legendary", "FangKarambit", "Mercúrio" },
		},
	},
	{
		id = "phantom", name = "Caixa Phantom", collection = "Coleção Assombro", price = 1200, section = "level", requiredLevel = 16,
		theme = "Névoa, aparições e ectoplasma",
		color = { 40, 60, 70 }, trim = { 120, 255, 200 },
		palette = { { 60, 80, 90 }, { 120, 255, 200 }, { 20, 30, 35 } },
		skins = {
			{ "Uncommon", "HornetMX", "Névoa" },
			{ "Rare", "LongbowSR", "Aparição" },
			{ "Epic", "RookR1", "Ectoplasma" },
			{ "Legendary", "TalonAR", "Assombro" },
			{ "Secret", "BowieAtlas", "Véu Fantasma" },
		},
	},
	{
		id = "elite", name = "Caixa Elite", collection = "Coleção Porcelana", price = 2500, section = "level", requiredLevel = 20,
		theme = "Porcelana, mármore e ouro branco",
		color = { 235, 235, 240 }, trim = { 215, 180, 90 },
		palette = { { 235, 235, 240 }, { 210, 180, 90 }, { 60, 110, 200 } },
		skins = {
			{ "Rare", "RookR1", "Porcelana" },
			{ "Rare", "GaleC4", "Safira" },
			{ "Epic", "TalonAR", "Coroa de Louros" },
			{ "Legendary", "FangKarambit", "Esmeralda Real" },
			{ "Secret", "Kestrel50", "Mármore Negro" },
		},
	},
	{
		id = "diamond", name = "Caixa Diamond", collection = "Coleção Lapidada", price = 5000, section = "level", requiredLevel = 28,
		theme = "Gemas, quartzo e facetas",
		color = { 120, 200, 240 }, trim = { 255, 255, 255 },
		palette = { { 150, 220, 250 }, { 240, 250, 255 }, { 80, 120, 200 } },
		skins = {
			{ "Rare", "Mako45", "Lapidado" },
			{ "Epic", "WaspK7", "Quartzo" },
			{ "Epic", "BastionR7", "Facetas" },
			{ "Legendary", "LongbowSR", "Brilhante" },
			{ "Secret", "LiraBorboleta", "Diamante Rosa" },
		},
	},
	{
		id = "royal", name = "Caixa Royal", collection = "Coleção Dinastia", price = 12000, section = "level", requiredLevel = 40,
		theme = "Dinastias, brasões e estandartes",
		color = { 150, 20, 30 }, trim = { 240, 190, 60 },
		palette = { { 170, 25, 35 }, { 235, 185, 60 }, { 40, 30, 80 } },
		skins = {
			{ "Rare", "HornetMX", "Brasão" },
			{ "Epic", "Kestrel50", "Estandarte" },
			{ "Legendary", "GaleC4", "Dinastia" },
			{ "Legendary", "CorvoFaca", "Cetro" },
			{ "Secret", "BowieAtlas", "Imperador" },
		},
	},
	{
		id = "mythic", name = "Caixa Mythic", collection = "Coleção Bestiário", price = 30000, section = "level", requiredLevel = 55,
		theme = "Criaturas lendárias e relíquias",
		color = { 40, 120, 80 }, trim = { 255, 140, 40 },
		palette = { { 40, 130, 90 }, { 255, 150, 50 }, { 30, 40, 40 } },
		skins = {
			{ "Epic", "RatchetV", "Hidra" },
			{ "Epic", "TalonAR", "Grifo" },
			{ "Legendary", "Kestrel50", "Fênix" },
			{ "Legendary", "FangKarambit", "Dragão de Jade" },
			{ "Secret", "LiraBorboleta", "Quimera" },
		},
	},
	{
		id = "infinity", name = "Caixa Infinity", collection = "Coleção Cosmos", price = 100000, section = "level", requiredLevel = 75,
		theme = "Nebulosas, supernovas e o infinito",
		color = { 20, 15, 45 }, trim = { 180, 120, 255 },
		palette = { { 30, 20, 70 }, { 180, 120, 255 }, { 255, 230, 150 } },
		skins = {
			{ "Epic", "BastionR7", "Horizonte de Eventos" },
			{ "Legendary", "LongbowSR", "Nebulosa" },
			{ "Legendary", "VespaP9", "Supernova" },
			{ "Secret", "CorvoFaca", "Buraco Negro" },
			{ "Secret", "BowieAtlas", "Infinito" },
		},
	},
	-- ===== Caixas Especiais (usam skins das coleções; não formam coleção nova) =====
	{
		id = "knives", name = "Caixa das Facas", section = "special", requiredLevel = 10,
		theme = "Só facas colecionáveis das coleções Fliperama a Porcelana",
		color = { 40, 40, 50 }, trim = { 230, 230, 240 },
		pool = { category = "Knife", collections = { "neon", "shadow", "chrome", "phantom", "elite" } },
	},
	{
		id = "snipers", name = "Caixa Precisão", section = "special", requiredLevel = 6,
		theme = "Armas de precisão das coleções iniciais",
		color = { 60, 80, 60 }, trim = { 160, 230, 120 },
		pool = { category = "Sniper", collections = { "tactical", "shadow", "phantom", "elite" } },
	},
	-- ===== Estoque Limitado (renova todo dia às 00:00 UTC) =====
	{
		id = "lucky", name = "Caixa Sortuda", section = "limited", requiredLevel = 12, stockPerDay = 5,
		theme = "Só Raras ou melhores das primeiras coleções",
		color = { 30, 140, 70 }, trim = { 120, 255, 140 },
		pool = { minTier = 3, collections = { "starter", "urban", "tactical", "neon", "shadow", "chrome" } },
	},
	{
		id = "flashcase", name = "Caixa Relâmpago", section = "limited", requiredLevel = 20, stockPerDay = 3,
		theme = "Só Épicas ou melhores das coleções Assombro, Porcelana e Lapidada",
		color = { 240, 200, 40 }, trim = { 255, 255, 255 },
		pool = { minTier = 4, collections = { "phantom", "elite", "diamond" } },
	},
}

CaseCatalog.Sections = {
	{ id = "level", name = "Caixas de Nível" },
	{ id = "special", name = "Caixas Especiais" },
	{ id = "limited", name = "Estoque Limitado" },
}

-- Valor esperado alvo de uma abertura, em fração do preço (a caixa consome créditos;
-- banco, missões e presentes compensam). Os valores das skins são escalados para atingir isto.
CaseCatalog.TargetExpectedValue = 0.90

return CaseCatalog
