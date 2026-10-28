# Testes obrigatórios

Situação de cada um dos 18 testes da especificação. "Automático" = coberto por `python3 tests/harness.py`.

| # | Teste | Como é verificado | Situação |
|---|---|---|---|
| 1 | Inventário persiste | `spec [1]` (ida e volta no formato do DataStore) e `server_smoke` "inventário e saldo persistem após reinício" | Automático ✅ |
| 2 | Cada abertura entrega o prêmio sorteado | `spec [2]` compara cada resultado com o sorteio esperado; fluxo de UI "loja → ABRIR → roleta → item no inventário" | Automático ✅ |
| 3 | Sem cobranças duplicadas | `spec [3]`; `server_smoke` "pedido repetido (mesmo requestId) não cobra duas vezes" | Automático ✅ |
| 4 | Abertura múltipla | `spec [4]`, `[4b]`, `[4c]`; fluxo de UI "abrir ×10" | Automático ✅ |
| 5 | Abertura automática pode ser interrompida | `spec [5]`; `server_smoke` "abertura automática respeita início/parada"; fluxo de UI com botão PARAR | Automático ✅ |
| 6 | Venda não duplica créditos | `spec [6]`, `[6b]`; `server_smoke` "venda via remote e proteção contra repetição" | Automático ✅ |
| 7 | Banco não duplica skins | `spec [7]` | Automático ✅ |
| 8 | Renda calculada corretamente | `spec [8]`, `[8b]` | Automático ✅ |
| 9 | Limite de produção offline | `spec [9]` | Automático ✅ |
| 10 | Patrimônio sem dupla contagem | `spec [10]` | Automático ✅ |
| 11 | Renascimento preserva o prometido | `spec [11]` | Automático ✅ |
| 12 | Oficina não consome sem entregar | `spec [12]`; fluxo de UI da oficina | Automático ✅ |
| 13 | Missões sem resgate repetido | `spec [13]`–`[13d]` (missões, diário, nível, coleção, conquista) | Automático ✅ |
| 14 | Rankings consistentes | `spec [14]`; ranking do servidor em `server_smoke` | Automático ✅ |
| 15 | HUD em computador e celular | Fluxo de UI confirma criação e atualização do HUD. **Conferir no Studio** em *Test → Device* (celular paisagem 800×360, tablet e 1920×1080): nada cortado, botões tocáveis | Manual ⚠️ |
| 16 | PvP e monstros bloqueados | `spec [16]` (FeatureFlags); nenhum serviço de combate é carregado em `Main.server.lua` | Automático ✅ |
| 17 | Proteção contra desconexão | `server_smoke`: desconexão grava e libera trava, perfil travado por outro servidor não é carregado, trava perdida impede sobrescrever, falhas temporárias são repetidas, `BindToClose` | Automático ✅ (confirmar também em servidor publicado) |
| 18 | Sem erros críticos multiplayer | `server_smoke` "vários jogadores simultâneos". **Conferir no Studio** com *Test → Clients and Servers* (3 jogadores) observando o Output | Parcial ⚠️ |

## Roteiro manual no Studio

1. Ativar *Enable Studio Access to API Services*; dar Play e confirmar no Output `[CASE STRIKE] servidor pronto` sem aviso de MODO MEMÓRIA.
2. Abrir cada botão dos dois menus laterais; Batalha deve mostrar "EM BREVE".
3. Abrir Urban ×1, ×5 e ×10, com e sem modo rápido; pular a animação; vender pela revelação.
4. Iniciar a abertura automática e parar pelo botão; zerar o saldo durante o automático e ver a parada sozinha.
5. Depositar 3 skins, sair do jogo, voltar alguns minutos depois e conferir que o acumulado cresceu (até o limite do cofre).
6. Favoritar uma skin e tentar vendê-la: deve exigir digitar `VENDER`.
7. Aplicar uma melhoria na oficina e conferir o efeito no modelo do inventário e no personagem (se equipada).
8. Em *Test → Clients and Servers* com 3 jogadores: abrir caixas ao mesmo tempo, ver anúncios de drops raros e o ranking do servidor.
9. Emulador de dispositivo em celular: checar HUD, roleta e painéis.
