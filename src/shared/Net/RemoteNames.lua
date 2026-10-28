-- RemoteNames: nomes dos RemoteEvents/RemoteFunctions criados pelo servidor em ReplicatedStorage.Remotes.

return {
	Functions = {
		"RequestCaseOpen", -- abrir caixas (resultado decidido no servidor)
		"InventoryAction", -- vender, favoritar, equipar, desequipar
		"BankAction", -- depositar, retirar, resgatar, melhorar
		"UpgradeAction", -- oficina
		"RequestData", -- pedir a fotografia completa do perfil
		"ProgressionAction", -- presentes, missões, coleções, conquistas, títulos, renascimento
		"LeaderboardRequest", -- ler rankings (cache do servidor)
	},
	Events = {
		"CaseOpenResult", -- avisos de abertura (ex.: drop raro anunciado a todos)
		"DataUpdated", -- servidor -> cliente: nova fotografia do perfil
	},
}
