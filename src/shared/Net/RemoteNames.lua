-- RemoteNames: nomes dos RemoteEvents/RemoteFunctions criados pelo servidor em ReplicatedStorage.Remotes.

return {
	Functions = {
		"RequestCaseOpen", -- abrir caixas (resultado decidido no servidor), automático, probabilidades
		"InventoryAction", -- vender, favoritar, equipar, expor no showroom, configurações
		"BankAction", -- depositar, retirar, resgatar, melhorar
		"UpgradeAction", -- oficina e variante de coleção
		"ClaimReward", -- presentes, missões, desafios de evento, coleções, conquistas
		"RequestData", -- pedir a fotografia completa do perfil
		"ProgressionAction", -- atributos, títulos, renascimento
		"LeaderboardRequest", -- ler rankings (cache do servidor)
	},
	Events = {
		"CaseOpenResult", -- avisos de abertura (ex.: drop raro anunciado a todos)
		"DataUpdated", -- servidor -> cliente: nova fotografia do perfil
	},
}
