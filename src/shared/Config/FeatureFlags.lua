-- FeatureFlags: funcionalidades reservadas para atualizações futuras.
-- Os serviços de combate NÃO existem nesta versão; os botões mostram "EM BREVE".

local FeatureFlags = {
	PvP = false, -- BLOQUEADO
	MonsterCombat = false, -- BLOQUEADO
	Bosses = false, -- BLOQUEADO
	Shooting = false, -- NÃO IMPLEMENTADO
	DamageAndCombat = false, -- NÃO IMPLEMENTADO
	SkinCrashGambling = false, -- NÃO IMPLEMENTADO (e não será: apostas não são permitidas)
	PlayerTrading = false, -- BLOQUEADO ATÉ REVISÃO DE SEGURANÇA E POLÍTICAS
	PaidRandomItems = false, -- nenhuma abertura aleatória ou moeda de caixa vendida por Robux
}

FeatureFlags.LockedLabel = "EM BREVE"

return FeatureFlags
