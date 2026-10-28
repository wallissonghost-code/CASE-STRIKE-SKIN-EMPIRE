-- UpgradeRecipes: oficina de melhorias. Todas as receitas têm RESULTADO GARANTIDO.
-- Nenhuma receita arrisca a skin ou multiplica seu valor; os efeitos são cosméticos.
-- O servidor valida raridade, créditos e materiais antes de consumir qualquer recurso.

local UpgradeRecipes = {}

UpgradeRecipes.List = {
	{
		id = "finish",
		displayName = "Acabamento superior",
		description = "Pintura metálica com reflexo e cores mais vivas.",
		effect = "Material metálico com reflexo no modelo e nas miniaturas.",
		minRarityTier = 1,
		creditsBase = 40,
		creditsValueFactor = 0.15,
		materials = { scrap = 6 },
		xp = 25,
	},
	{
		id = "holo",
		displayName = "Variante holográfica",
		description = "Superfície translúcida que muda de cor conforme o ângulo.",
		effect = "Peças principais em vidro iridescente.",
		minRarityTier = 2,
		creditsBase = 150,
		creditsValueFactor = 0.22,
		materials = { scrap = 10, pigment = 3 },
		xp = 45,
	},
	{
		id = "gold",
		displayName = "Variante dourada",
		description = "Banho de ouro nas peças principais.",
		effect = "Corpo da arma em ouro polido.",
		minRarityTier = 3,
		creditsBase = 300,
		creditsValueFactor = 0.25,
		materials = { scrap = 14, pigment = 4 },
		xp = 60,
	},
	{
		id = "particles",
		displayName = "Efeito de partículas",
		description = "Faíscas na cor da raridade ao redor da skin.",
		effect = "Emissor de partículas leve (limitado para celulares).",
		minRarityTier = 3,
		creditsBase = 350,
		creditsValueFactor = 0.22,
		materials = { scrap = 12, pigment = 4, core = 1 },
		xp = 60,
	},
	{
		id = "frame",
		displayName = "Moldura especial",
		description = "Moldura com gradiente no cartão do inventário e do índice.",
		effect = "Contorno em gradiente nos cartões.",
		minRarityTier = 1,
		creditsBase = 80,
		creditsValueFactor = 0.10,
		materials = { scrap = 8, pigment = 1 },
		xp = 30,
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
	},
}

UpgradeRecipes.ById = {}
for i, r in ipairs(UpgradeRecipes.List) do
	r.order = i
	UpgradeRecipes.ById[r.id] = r
end
UpgradeRecipes.Count = #UpgradeRecipes.List

-- custo em créditos para uma skin específica (determinístico, exibido antes da confirmação)
function UpgradeRecipes.creditCost(recipe, skinValue)
	return math.floor(recipe.creditsBase + skinValue * recipe.creditsValueFactor + 0.5)
end

return UpgradeRecipes
