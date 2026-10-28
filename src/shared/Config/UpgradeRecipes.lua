-- UpgradeRecipes: oficina de melhorias. Todas as receitas têm RESULTADO GARANTIDO.
-- Nenhuma receita arrisca a skin ou multiplica seu valor; os efeitos são cosméticos.

local UpgradeRecipes = {}

UpgradeRecipes.List = {
	{
		id = "finish",
		displayName = "Acabamento superior",
		description = "Pintura com reflexo metálico e cores mais vivas.",
		effect = "Material metálico no modelo e nas prévias.",
		minRarityTier = 1,
		creditsBase = 40,
		creditsValueFactor = 0.15,
		materials = { scrap = 6 },
		xp = 25,
		order = 1,
	},
	{
		id = "glow",
		displayName = "Efeito de brilho",
		description = "Partes de destaque passam a emitir luz.",
		effect = "Destaques em neon e luz suave ao redor da skin.",
		minRarityTier = 2,
		creditsBase = 120,
		creditsValueFactor = 0.25,
		materials = { scrap = 10, pigment = 2 },
		xp = 40,
		order = 2,
	},
	{
		id = "frame",
		displayName = "Moldura especial",
		description = "Moldura animada no cartão do inventário.",
		effect = "Contorno com gradiente na grade do inventário e no índice.",
		minRarityTier = 1,
		creditsBase = 80,
		creditsValueFactor = 0.10,
		materials = { scrap = 8, pigment = 1 },
		xp = 30,
		order = 3,
	},
	{
		id = "inspect",
		displayName = "Animação de inspeção",
		description = "A inspeção 3D ganha giro e balanço exclusivos.",
		effect = "Animação de inspeção estendida.",
		minRarityTier = 3,
		creditsBase = 250,
		creditsValueFactor = 0.20,
		materials = { scrap = 12, pigment = 3 },
		xp = 50,
		order = 4,
	},
	{
		id = "variant",
		displayName = "Variante da coleção",
		description = "Inverte a paleta usando as cores da coleção.",
		effect = "Esquema de cores alternativo da coleção.",
		minRarityTier = 4,
		creditsBase = 600,
		creditsValueFactor = 0.30,
		materials = { scrap = 20, pigment = 5, core = 1 },
		xp = 90,
		order = 5,
	},
}

UpgradeRecipes.ById = {}
for _, r in ipairs(UpgradeRecipes.List) do
	UpgradeRecipes.ById[r.id] = r
end

-- custo em créditos para uma skin específica (determinístico, exibido antes da confirmação)
function UpgradeRecipes.creditCost(recipe, skinValue)
	return math.floor(recipe.creditsBase + skinValue * recipe.creditsValueFactor + 0.5)
end

return UpgradeRecipes
