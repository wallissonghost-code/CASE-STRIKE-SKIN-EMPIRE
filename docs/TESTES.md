# Registro de testes — MUTANT FACTORY

Executados com `python3 tests/harness.py` em 28/10/2026:
- **30 testes de lógica** e **32 de servidor + cliente**, todos passando.
- `tests/check_requires.py`: 106 requires verificados, sem erros.

"Simulado" = `Main.server.lua` e `Main.client.lua` reais rodando em `tests/roblox_mock.lua`, com:
- DataStore em memória, inclusive falhas;
- relógio virtual;
- personagens com posição;
- botões de proximidade disparados;
- cliques reais na interface.

Isso **não substitui o Roblox Studio**: física, câmera, renderização e rede real só aparecem lá (roteiro abaixo).

| Área | O que foi verificado | Resultado |
|---|---|---|
| Carga e salvamento | trava de sessão, saída libera a trava, reinício do servidor mantém moedas e criaturas, perfil travado por outro servidor não carrega, falhas temporárias repetidas | ✅ simulado |
| Bases | 6 bases, jogador levado até a sua, 7º jogador recebe aviso de servidor cheio | ✅ simulado |
| Esteira | criaturas aparecem e andam; compra só de perto, pelo preço do servidor; quem chega depois recebe "outra pessoa comprou" | ✅ simulado |
| Ovos | cobrança única com `requestId` repetido, preço do cliente ignorado, limite de frequência, chances somam 100%, 100 mil sorteios seguem as chances, valor esperado ≈ preço | ✅ |
| Renda | por horário, limite do cofre, offline, relógio voltando, poção e evento de renda só no período certo, cofre maior não perde nem duplica | ✅ |
| Coleta | só dentro da própria base | ✅ simulado |
| Roubo | proteção de novato, pegar (prompt), vítima avisada, venda travada durante o roubo, mais devagar carregando, entrega muda o dono e salva os dois perfis | ✅ simulado |
| Roubo — devolução | dono encosta (defesa), tempo esgotado, escudo ligado com ladrão dentro, ladrão sai do servidor | ✅ simulado |
| Roubo — bloqueios | escudo ativo, criatura protegida por 3 min, base do ladrão cheia | ✅ |
| Escudo | só dentro da base, empurra visitantes, não liga duas vezes | ✅ simulado |
| Melhorias, poções, venda | custos, níveis máximos, efeitos, confirmação para Lendária/Mítica | ✅ |
| Missões, presentes, índice | progresso por evento, resgate único, recompensa proporcional à renda, sequência diária, marcos | ✅ |
| Renascer | frase de confirmação, custo, mantém índice/melhorias, bloqueado com criatura sendo roubada | ✅ |
| Eventos | agenda fixa, aviso a todos, chances mudam; evento de teste só no Studio | ✅ |
| Integridade | perfil corrompido reparado (moedas, pedestais duplicados, criaturas inexistentes) | ✅ |
| Interface | HUD, 9 painéis abrem, abrir ovo, melhorar, presente, aviso de roubo | ✅ simulado |

## Roteiro manual no Roblox Studio

1. Gere o place com `python3 tools/build_place.py`, abra `MutantFactory.rbxlx` e dê Play.
   - O Output deve mostrar `[MUTANT FACTORY] servidor pronto`.
   - Você deve aparecer na sua base.
2. Teste a esteira: vá até a praça, aperte E numa criatura da esteira e confira que ela aparece num pedestal da sua base.
3. Teste os ovos: abra o Ovo Básico no quiosque. A animação deve tocar e a criatura deve ir para a base.
4. Espere 1 minuto e colete no terminal amarelo.
5. Teste o roubo com *Test → Clients and Servers*, 2 jogadores:
   - espere 2 min (proteção de novato);
   - com o jogador 2, entre na base do 1, segure E numa criatura e corra até a própria base;
   - repita e, com o jogador 1, encoste no ladrão;
   - repita e trave a base com o ladrão dentro.
6. Escudo: com ele ativo, o jogador 2 deve ser levado para fora ao tentar entrar.
7. Persistência:
   - publique, ative *Enable Studio Access to API Services*;
   - saia e volte: moedas e criaturas devem continuar;
   - volte depois de alguns minutos: as moedas guardadas devem ter crescido.
8. Celular: use o emulador de dispositivos (celular paisagem e tablet). Nada deve ficar cortado e os botões devem ser tocáveis.
9. Desempenho: com 6 jogadores e 20 criaturas cada, acompanhe *Developer Console → Memory* e o *MicroProfiler*.
