# Registro de testes — V4.0

Executados com `python3 tests/harness.py` em 28/10/2026: **56 testes de lógica e 39 de servidor+cliente, todos passando** (inclui zonas, poções, eventos 2X, loja em seções e estoque limitado), mais `tests/check_requires.py` sem erros.

"Simulado" = servidor (`Main.server.lua`) e cliente (`Main.client.lua`) reais rodando em `tests/roblox_mock.lua`, com DataStore em memória (inclusive falhas), relógio virtual e cliques reais nos botões da interface. Não substitui o Roblox Studio: itens marcados ⚠️ precisam do roteiro manual abaixo.

| # | Teste obrigatório | Evidência automática | Resultado |
|---|---|---|---|
| 1 | Entrada e carregamento de dados | "perfil carrega com trava de sessão e envia fotografia", "cliente inicia sem erros e recebe a fotografia" | ✅ simulado |
| 2 | Saldo inicial | `preços e níveis das 12 caixas` (500 créditos); fotografia inicial com ₵ 500 | ✅ |
| 3 | Compra de caixas | `[3] sem cobranças duplicadas`, "abrir caixa via remote desconta e entrega", níveis de bloqueio | ✅ |
| 4 | Sorteio correto | `[2]` (cada abertura entrega o sorteado), simulação de 200 mil sorteios, validador de RNG, soma 100% com e sem sorte | ✅ |
| 5 | Animação da roleta | fluxo de UI "loja → ABRIR → roleta → item no inventário" | ✅ simulado ⚠️ visual no Studio |
| 6 | Abertura múltipla | `[4]` atômica, `[4b]` inventário cheio, ×10 pela UI, ×25 com atributo (lógica e UI, sem faixas animadas) | ✅ |
| 7 | Abertura automática | `[5]` limites e parada; remotes start/stop; botão PARAR na UI | ✅ |
| 8 | Venda de skins | `[6]`, `[6b]` favoritas, venda de Secreta exige confirmação (lógica e remote) | ✅ |
| 9 | Depósito no banco | `[7]` sem duplicar; vagas; depósito pela UI | ✅ |
| 10 | Resgate da renda | `[8]`, resgate pelo remote e pela UI | ✅ |
| 11 | Produção offline | `[9]` limite e cofre; "limite offline aumenta com a melhoria"; relógio voltando não gera créditos | ✅ |
| 12 | Cálculo de patrimônio | `[10]` sem dupla contagem, pendente incluído uma vez, resgate não altera | ✅ |
| 13 | Inspeção 3D | fluxo de UI: inspecionar, aproximar, afastar, giro automático, fechar | ✅ simulado ⚠️ arrastar no Studio |
| 14 | Melhorias | `[12]` não consome sem entregar; variante de coleção; oficina pela UI | ✅ |
| 15 | Progressão de XP | curva gradual, limite diário, bônus de XP, títulos por nível, XP de conquistas | ✅ |
| 16 | Renascimento | `[11]` preserva raras, favoritas, índice e conquistas; confirmação digitada | ✅ |
| 17 | Missões | `[13]`, `[13b]`, missões de coleção e nível, sem resgate repetido | ✅ |
| 18 | Presentes | `[13c]` diário e de nível sem duplicar; presente diário pela UI | ✅ |
| 19 | Coleções | `[13d]` recompensa única, título e cosméticos; variante exclusiva | ✅ |
| 20 | Rankings | `[14]` consistentes (incluindo renda do banco); ranking do servidor via remote | ✅ |
| 21 | Reconexão após falha | falhas temporárias de DataStore repetidas; desconexão libera trava; reinício do servidor mantém inventário e saldo | ✅ simulado |
| 22 | Proteção contra duplicação | `requestId` repetido não cobra duas vezes; venda repetida falha; perfil travado por outro servidor não é carregado; trava perdida impede sobrescrever | ✅ |
| 23 | Interface mobile | ScreenGuis com UIScale (1280×720 base) criadas e todos os painéis abrem | ⚠️ conferir no emulador de dispositivos |
| 24 | Uso de memória | sem medição automática | ⚠️ medir no Studio (Developer Console → Memory) |
| 25 | Servidores com vários jogadores | "vários jogadores simultâneos não interferem" (3 jogadores) | ✅ simulado ⚠️ confirmar com Clients and Servers |

PvP, monstros e combate: `[16]` confirma todos os bloqueios em `FeatureFlags` e nenhum serviço de combate é carregado.

## Roteiro manual no Roblox Studio

1. Gerar `CaseStrike.rbxlx` (`python3 tools/build_place.py`), abrir e dar Play. O Output deve mostrar `[CASE STRIKE] servidor pronto` sem avisos de validação.
2. Publicar o place, ativar *Enable Studio Access to API Services*, sair e voltar: saldo e inventário devem persistir.
3. Abrir cada botão dos menus; Batalha e portais mostram "EM BREVE".
4. Abrir Starter ×1, ×5, ×10 e ×25 (após comprar o atributo); testar modo rápido, pular animação, reduzir efeitos e abertura automática com PARAR.
5. Inspecionar uma skin: arrastar para girar, roda do mouse para aproximar.
6. Depositar skins, sair por alguns minutos e voltar: o acumulado cresce até o cofre e o limite offline.
7. Expor skins no showroom e visitar a vitrine com outro jogador (*Test → Clients and Servers*, 3 jogadores).
8. Emulador de dispositivos (celular paisagem, tablet, 1920×1080): nada cortado, botões tocáveis.
9. Developer Console → Memory: acompanhar memória após 10 minutos de abertura automática.
