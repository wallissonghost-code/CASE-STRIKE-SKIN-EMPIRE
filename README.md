# CASE STRIKE RNG — Skin Empire

Simulador Roblox de abertura de caixas e coleção de skins fictícias, com banco de renda passiva, oficina de melhorias, atributos, showroom e eventos. Escrito em Luau, organizado como projeto **Rojo**. Projeto independente (não compartilha código, workflows nem segredos com outros jogos).

**Versão: V4.0.** O servidor decide saldo, sorteios, propriedade de itens, renda e persistência; o cliente só apresenta, anima e envia pedidos.

> Ciclo: abrir caixas → receber skins → colecionar → vender ou depositar → gerar créditos → melhorar → desbloquear caixas → evoluir → completar coleções → participar de eventos.

---

## Como testar

**Sem instalar nada além do Studio**

```bash
python3 tools/build_place.py   # gera CaseStrike.rbxlx
```

Abra `CaseStrike.rbxlx` no Roblox Studio e aperte **Play**. O lobby, as interfaces e os remotes são criados por código. O CI também gera esse arquivo a cada push (artefato `CaseStrikeRNG-place` em Actions).

**Com Rojo (desenvolvimento)**: `rojo serve` e **Connect** no plugin do Studio.

**Salvamento**: o place precisa estar publicado e com *Game Settings → Security → Enable Studio Access to API Services* ligado. Sem isso o jogo roda em **modo memória** (avisa no Output e não salva).

## Testes automatizados

```bash
pip install lupa
python3 tests/harness.py        # sintaxe + lógica + servidor e cliente reais em Roblox simulado
python3 tests/check_requires.py # todo require aponta para um módulo existente
python3 tools/gen_catalog.py    # regenera docs/CATALOGO.md
```

| Camada | O que roda | Testes |
|---|---|---:|
| Sintaxe | todos os arquivos de `src/` | — |
| Lógica (`tests/spec.lua`) | conteúdo, RNG, economia, banco, oficina, atributos, zonas, poções, eventos 2X, estoque, missões, renascimento, integridade | 56 |
| Servidor + cliente (`tests/server_smoke.lua`) | `Main.server.lua` e `Main.client.lua` reais num Roblox simulado (`tests/roblox_mock.lua`): DataStore em memória com falhas, relógio virtual, cliques reais na interface | 39 |

Registro dos 25 testes obrigatórios: [`docs/TESTES.md`](docs/TESTES.md). O código de `src/` usa um subconjunto de Luau compatível com o parser Lua (sem anotações de tipo, sem `+=`, sem `continue`) para poder ser testado fora do Studio.

**Importante:** os testes automáticos rodam num ambiente Roblox *simulado*. O jogo ainda não foi executado no Roblox Studio nem publicado por este projeto. O roteiro manual no Studio está em `docs/TESTES.md`.

---

## Estrutura

```
src/
  shared/                  -> ReplicatedStorage.Shared
    Config/                CaseCatalog (fonte única das caixas e coleções), CaseDefinitions,
                           SkinDefinitions, RarityConfig, EconomyConfig, BankConfig, UpgradeRecipes,
                           MissionDefinitions, ProgressionConfig, EventDefinitions, AttributeConfig,
                           LuckConfig, AchievementDefinitions, AudioConfig, FeatureFlags
    Logic/                 regras puras e testáveis
      ProfileOps           TODAS as operações que alteram o perfil (atômicas)
      DropValidator        valida pesos, itens, probabilidades, requisitos e referências
      Probability          chances finais, sorteio, % exibidos que somam 100
      BankMath / Wealth    renda por timestamps; patrimônio sem dupla contagem
      ProfileSchema        perfil padrão, migração (v1 → v2) e integridade
      ClientView           fotografia enviada ao cliente
    Visual/                modelos 3D estilizados gerados por código (skins e caixas)
  server/                  -> ServerScriptService.Server
    Core/                  Remotes (validação, rate limit, deduplicação), Validate, RateLimiter
    Services/              PlayerData, Lobby, Case, Inventory, Economy, Bank, Upgrade, Collection,
                           Mission, Event, Reward, Progression, Leaderboard, Showroom
  client/                  -> StarterPlayerScripts.Client
    Controllers/           UI, HUD, Case (roleta), Shop, Inventory, Bank, Upgrade, Collection,
                           ProgressionPanels (Missões/Presentes/Sorte/Atributos/Renascer),
                           Leaderboard, Lobby
    Util/                  Net (requestId + indicador de carregamento), Store, Signal
```

As interfaces são ScreenGuis próprias criadas em `PlayerGui`: **MainHUD, CaseShop, CaseOpening, Inventory, Bank, UpgradeWorkshop, Collections, Missions, Rewards, Rankings**, além de Attributes, Panels, Dialogs e Toasts. São montadas por código (não há arquivos de StarterGui) com a mesma linguagem visual e uma UIScale responsiva.

### Remotes (`ReplicatedStorage.Remotes`)

| Remote | Ações |
|---|---|
| `RequestCaseOpen` | `open`, `startAuto`, `stopAuto`, `odds` |
| `InventoryAction` | `sell`, `sellBulk`, `favorite`, `equip`, `unequip`, `showcase`, `setFastOpen`, `setReduceEffects` |
| `BankAction` | `deposit`, `withdraw`, `claim`, `upgrade` |
| `UpgradeAction` | `apply`, `collectionVariant` |
| `ClaimReward` | `claimDaily`, `claimLevelReward`, `claimMission`, `claimEventChallenge`, `claimCollection`, `claimAchievement` |
| `ProgressionAction` | `buyAttribute`, `setTitle`, `rebirth` |
| `RequestData` | `get` |
| `LeaderboardRequest` | `get` |
| `DataUpdated` (evento) | servidor → cliente: fotografia do perfil |
| `CaseOpenResult` (evento) | anúncio de drops Lendários/Secretos e início/fim de eventos |

Toda chamada passa por: formato validado → limite de frequência → deduplicação por `requestId` → `pcall` → cópia de segurança do perfil (revertida em qualquer falha).

---

## Funcionalidades implementadas (V4.0)

- **Mapa compacto**: praça com spawn e vitrine das 12 caixas; loja, banco, oficina, museu/índice, missões, área de presentes; showroom com 12 vitrines; painel físico de rankings; 4 portais "EM BREVE" (Arena PvP, Masmorra, Torre dos Chefes, Mercado de Trocas); árvores, arbustos e pedras.
- **HUD**: menus esquerdo (Batalha bloqueada, Inventário, Renascimento, Loja, Banco) e direito (Presentes, Índice, Sorte, Missões, Atributos, Melhorador); botão CAIXAS; saldo, patrimônio, equipamentos, renda/s, nível e barra de XP; evento atual e próximo evento; avisos (!) de recompensas prontas. Ao abrir um painel, os elementos secundários do HUD somem.
- **Placa acima do personagem**: nome, título, nível e patrimônio resumido.
- **12 caixas** (Starter 10 → Infinity 100.000) com coleção própria, modelo, tema, requisitos de nível (Starter 1, Neon 5, Elite 20, Royal 40, Infinity 75…) e tabela de recompensas. Novas caixas/coleções entram só por dados em `CaseCatalog.lua`.
- **Janela da caixa**: modelo 3D, quantidade, preço unitário e total, ×1/×5/×10/×25 (×25 pelo atributo), rápida, automática com cancelamento, grade rolável de recompensas com imagem, nome, valor, raridade, coleção e probabilidade final vinda do servidor.
- **Roleta**: resultado decidido e registrado antes da animação; efeitos por raridade (azul, roxo, dourado e animação especial da Secreta com tremor e faixa); opção **Reduzir efeitos visuais**; ×25 sem faixas animadas (só a grade); abertura automática sequencial com limites.
- **RNG**: 6 raridades, pesos configuráveis por caixa, `DropValidator` na inicialização (caixa inválida fica indisponível), sorte transparente com teto de +25%.
- **60 skins** em 5 categorias, cada uma com definição, instância única, coleção, acabamento, modelo 3D, miniatura em ViewportFrame e data de obtenção.
- **Inventário**: grade paginada; filtros por nome, categoria, raridade, coleção, valor e data; inspecionar, favoritar, equipar, vender, depositar, oficina, expor no showroom. Favoritas e Lendárias/Secretas exigem digitar `VENDER` (e o servidor exige `confirmValuable`); Raras/Épicas mostram aviso extra.
- **Inspeção 3D**: arrastar gira, roda do mouse e botões aproximam/afastam, informações e efeitos aplicados.
- **Banco**: vagas livres e bloqueadas, renda por skin e total, acumulado ao vivo, RESGATAR e RETIRAR; melhorias de capacidade, eficiência, armazenamento, **limite offline** e exposição, com benefício atual → seguinte antes da compra.
- **Patrimônio**: saldo + todas as skins (inventário e banco, uma vez cada) + pendente do banco. Resgatar não altera o patrimônio.
- **Oficina**: acabamento superior, variante holográfica, variante dourada, efeito de partículas, moldura especial e animação de inspeção, com prévia 3D do resultado garantido; variante exclusiva grátis para coleções concluídas.
- **Atributos**: sorte, eficiência do banco, capacidade de banco, bônus de XP, velocidade de abertura e limite de abertura múltipla, com nível, limite, custo, benefício atual e seguinte.
- **Níveis e títulos**: Novato, Colecionador, Especialista, Magnata, Mestre e Lendário por nível, mais títulos de coleção, evento e renascimento; XP por descobertas, coleções, missões, melhorias e conquistas.
- **Renascimento**: requisitos, mantido × reiniciado; preserva skins Raras ou melhores, favoritas, coleções, conquistas, atributos e cosméticos; confirmação `RENASCER`.
- **Presentes, missões, índice, eventos e rankings**: diário de 7 dias pelo relógio do servidor, recompensas por nível e conquista; 3 diárias + 3 semanais (incluindo completar coleção e subir de nível); índice com silhuetas, % de progresso e recompensas de coleção (título, moldura, vitrine temática e variante); eventos Halloween, Semana Neon, Natal e Aniversário com datas reais; rankings de patrimônio, nível, skins únicas, coleções, conquistas e renda do banco, com cache.
- **Zonas com sorte** (`ZoneConfig.lua`): Zona 2 Campos Floridos, Zona 3 Vale Assombrado e Zona 4 Cume Cristalino, cada uma com +5% de sorte enquanto o personagem estiver dentro. Desbloqueio em ordem com créditos e nível; o servidor detecta a posição a cada segundo e o cliente mostra barreiras só nas zonas ainda bloqueadas e o aviso "Zona 3 + 5% Sorte" ao entrar.
- **Poções** (`PotionConfig.lua`): Sorte (+10%), XP (×2) e Renda (×1,5 no banco), ganhas em presentes, missões, níveis e conquistas, ativadas pelos ícones com tempo restante no HUD.
- **Eventos relâmpago 2X** (`EventDefinitions.Flash`): a cada 3 h por 20 min, alternando 2X Sorte ("Evento de Trevo"), 2X XP e 2X Renda, com contagem real no topo da tela.
- **Loja em seções**: Caixas de Nível (as 12 coleções), Caixas Especiais (Facas e Precisão) e Estoque Limitado (Sortuda 5/dia e Relâmpago 3/dia, renovação às 00:00 UTC). O preço das especiais é o valor esperado do sorteio ÷ 0,90.
- **Índice por raridade**: progresso de itens Comuns, Incomuns, Raros, Épicos, Lendários e Secretos; e a skin equipada de maior valor aparece acima da cabeça, junto da placa.
- **Persistência**: um documento por jogador, trava de sessão com `UpdateAsync`, salvamento automático, rápido e na saída, `BindToClose`, tentativas limitadas, registro das últimas transações e integridade ao carregar. Se os dados não carregarem com segurança, o jogador é desconectado com aviso em vez de receber um perfil vazio.
- **Publicação GitHub → Roblox**: `.github/workflows/publish.yml` (manual, exige digitar `PUBLICAR`, roda os testes e usa a API oficial de publicação de places do Open Cloud). Precisa dos secrets `ROBLOX_API_KEY`, `ROBLOX_UNIVERSE_ID` e `ROBLOX_PLACE_ID`.

**Bloqueado / não implementado**: PvP, monstros, chefes, armas com dano, batalhas com apostas, crash, trocas entre jogadores, compra de créditos de caixa com Robux.

## Configurando

| Quer mudar... | Arquivo |
|---|---|
| Caixas, coleções, preços, níveis, pesos, skins | `Config/CaseCatalog.lua` |
| Peso e fator de valor por raridade | `Config/RarityConfig.lua` |
| Saldo inicial, venda, confirmações, showroom, abertura | `Config/EconomyConfig.lua` |
| Banco | `Config/BankConfig.lua` |
| Atributos | `Config/AttributeConfig.lua` |
| Oficina | `Config/UpgradeRecipes.lua` |
| Missões | `Config/MissionDefinitions.lua` |
| XP, títulos, recompensas, renascimento | `Config/ProgressionConfig.lua` |
| Eventos e datas | `Config/EventDefinitions.lua` |
| Sons por raridade | `Config/AudioConfig.lua` |

Depois de mudar valores, rode `python3 tests/harness.py` (o validador e os testes de valor esperado acusam tabelas inconsistentes).

## Pendências e problemas conhecidos

- **Não testado no Roblox Studio nem publicado.** Layout em aparelhos reais, uso de memória e sessões multiplayer reais precisam do roteiro manual em `docs/TESTES.md`.
- **Sons vazios**: `AudioConfig.lua` vem sem IDs (o projeto não inventa assets). Faça upload dos seus sons e cole os IDs.
- **Modelos gerados por código**: são estilizados e leves, mas simples. Para uma versão comercial, troque por modelos próprios mantendo `SkinModelFactory.build(def, upgrades)`.
- **Perfis da v0.2** são migrados, mas skins com IDs que deixaram de existir são removidas pela verificação de integridade (os IDs das skins mudaram com as 12 coleções).
- O Índice renderiza 60 miniaturas 3D estáticas e a oficina lista as 60 skins de maior valor; em aparelhos muito fracos pode valer trocar por imagens pré-renderizadas.
- O workflow de publicação só funciona depois de criar a experiência no Roblox e configurar os secrets.
- O módulo `Services/CollectionService.lua` é do jogo; não confundir com o serviço `CollectionService` do Roblox.
