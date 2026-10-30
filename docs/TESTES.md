# Registro de testes — MYSTERY MACHINE

Executados com `python3 tests/harness.py` em 30/10/2026:
- **27 testes de lógica** (`tests/spec.lua`) e **39 de servidor + cliente** (`tests/server_smoke.lua`), todos passando;
- `tests/check_requires.py`: todos os `require` apontam para módulos existentes.

"Simulado" significa: `Main.server.lua` e `Main.client.lua` reais rodando em `tests/roblox_mock.lua`, com
DataStore em memória (inclusive falhas), relógio virtual, personagens com posição, prompts e toques
disparados e cliques reais nos botões da interface. O mock também falha se o código atribuir uma
propriedade que não existe numa instância. **Isso não substitui o Roblox Studio** (física, render,
câmera, rede real e DataStore real).

## Critérios de aceitação

| # | Critério | Situação |
|---|---|---|
| 1 | Jogador consegue entrar | ✅ simulado (perfil carrega, HUD aparece) — conferir no Studio |
| 2 | Máquina visível | ✅ modelo criado (corpo, visor, compartimento, botão, luzes, placa) — **conferir visual no Studio** |
| 3 | Interação funciona | ✅ simulado (prompt abre o painel, USAR MÁQUINA) |
| 4 | Saldo descontado corretamente | ✅ (inclui preço enviado pelo cliente ignorado e requestId repetido) |
| 5 | Resultado calculado no servidor | ✅ (`Random` do servidor; 200 mil sorteios seguem as chances) |
| 6 | Objeto premiado aparece visualmente | ✅ simulado (modelo no compartimento e no painel) — **conferir no Studio** |
| 7 | Item entra no inventário | ✅ |
| 8 | Venda funciona | ✅ (valor do servidor, confirmação, favoritos, expostos) |
| 9 | Saldo atualiza | ✅ (HUD e leaderstats) |
| 10 | Dados persistem após sair | ✅ simulado (saída salva e libera trava; outro servidor carrega) — **conferir com DataStore real** |
| 11 | Nível e XP funcionam | ✅ |
| 12 | Coleções registram descobertas | ✅ |
| 13 | Melhorias funcionam | ✅ |
| 14 | Interface em dispositivos móveis | ⚠️ escala por UIScale implementada; **conferir no emulador de dispositivos** |
| 15 | Sem erros críticos conhecidos de duplicação ou perda de dados | ✅ nos cenários testados (lista abaixo) |

## O que foi verificado

| Área | Cenários | Resultado |
|---|---|---|
| Configuração | 4 máquinas com preços/níveis do design, 20 objetos únicos, cada um na máquina de origem, chances somam 100% e a tela mostra as mesmas usadas no sorteio | ✅ |
| Sorteio e economia | limites do sorteio, distribuição em 200 mil aberturas, retorno médio de 85–97% do preço | ✅ |
| Máquina | longe recusa, cobra o preço, entrega, anima para todos, preço/resultado do cliente ignorados, requestId repetido, intervalo mínimo, limite de frequência, bloqueio por nível, inventário cheio, sem saldo | ✅ |
| Inventário e venda | venda única, quantidades inválidas, favoritos protegidos, confirmação de raros, vender repetidos | ✅ |
| Vitrine | modelo 3D e placa no estande, não expõe mais do que possui, exposto não vende, retirar | ✅ |
| Progressão | curva de níveis, recompensa de nível paga uma vez, XP de abertura com limite diário, melhorias e limites | ✅ |
| Missões e presentes | 3 por dia com 1 gratuita, resgate único, troca diária, conquistas, presente com sequência | ✅ |
| Moedas perdidas | só perto, limite por hora, reaparecem; jogador zerado consegue voltar a jogar | ✅ |
| Coleção e títulos | recompensa única, título exibido acima da cabeça | ✅ |
| Dados | trava de sessão, autosave com falha temporária, saída, desligamento, outro servidor com o perfil aberto, falha de carregamento sem sobrescrever, perfil corrompido reparado, modo memória | ✅ simulado |
| Erro no meio de operação | perfil restaurado | ✅ |
| Ranking | servidor (memória) e global (OrderedDataStore) com cache | ✅ simulado |
| Interface | HUD, 7 painéis do menu (um por vez), painel da máquina com chances, usar/pular/resultado, vender pelo resultado, inventário, melhorias, presente, coleção/títulos, configurações, ranking, avisos | ✅ simulado |

## Roteiro manual no Roblox Studio (antes de publicar)

1. `python3 tools/build_place.py`, abra `MysteryMachine.rbxlx` e dê Play.
   O Output deve mostrar `[MYSTERY MACHINE] servidor pronto` e nenhum erro vermelho.
2. **Visual:** ande pelo parque: praça com fonte, 4 máquinas ao norte, loja a leste, ranking a oeste,
   galeria ao sul, área "em breve". Confira se nada flutua, atravessa ou está virado.
3. **Máquina Comum:** aperte E no botão, use, veja luzes, cápsulas e o objeto no compartimento. Teste PULAR.
4. **Inventário:** venda, favorite, venda repetidos, exponha e vá até a galeria ver o objeto.
5. **Sem saldo:** gaste tudo e recupere com moedas perdidas e presente diário.
6. **Melhorias:** compre velocidade e confira a animação mais curta.
7. **Dois jogadores** (*Test → Clients and Servers*): um vê a máquina do outro animar e visita a vitrine dele.
8. **Persistência:** publique, ative *Enable Studio Access to API Services*, saia e volte.
9. **Celular e tablet:** emulador de dispositivos em paisagem e retrato; nada cortado, botões tocáveis.
10. **Desempenho:** com 8 jogadores, acompanhe *Developer Console → Memory* e o *MicroProfiler*.
