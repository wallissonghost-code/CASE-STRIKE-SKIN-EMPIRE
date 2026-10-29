-- RemoteNames: remotes criados pelo servidor em ReplicatedStorage.Remotes.

return {
	Functions = {
		"RequestData", -- fotografia completa do perfil
		"EggAction", -- abrir ovo, comprar/usar poção
		"BaseAction", -- coletar, vender, melhorias, escudo, mover criatura
		"ClaimAction", -- missões, presente diário, marcos do índice, renascer
		"SettingsAction", -- ajustes
		"RankingRequest", -- ranking do servidor
	},
	Events = {
		"DataUpdated", -- servidor -> cliente: nova fotografia
		"Notify", -- avisos (roubo em andamento, ladrão pego, compras na esteira, eventos)
	},
}
