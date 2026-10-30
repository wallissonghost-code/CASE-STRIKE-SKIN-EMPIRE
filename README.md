# 🎰 MYSTERY MACHINE — Máquina Surpresa

Jogo de Roblox de coleção: use máquinas misteriosas, ganhe objetos de 6 raridades, venda ou
guarde, complete o livro de coleções, exponha seus favoritos na galeria e evolua para
desbloquear máquinas melhores.

**Ciclo:** inserir moeda → ativar máquina → receber objeto → guardar ou vender → evoluir.

> **Situação:** servidor e interface reais rodam inteiros num ambiente Roblox **simulado**, com
> 66 testes automáticos passando (27 de lógica + 39 de servidor e cliente).
> O jogo **ainda não foi aberto no Roblox Studio nem publicado**: física, renderização, câmera e
> rede real só podem ser conferidas lá. Siga o roteiro de [docs/TESTES.md](docs/TESTES.md) antes de publicar.

## Abrir no Roblox Studio

- **Sem ferramentas:** abra `MysteryMachine.rbxlx` (File → Open) e clique em Play. O parque é
  construído por código ao iniciar.
- **Com Rojo:** `rojo serve` (usa `default.project.json`).
- **Gerar o place de novo** depois de mudar o código: `python3 tools/build_place.py`.
- **Salvar progresso no Studio:** publique como experiência de teste e ative
  *Game Settings → Security → Enable Studio Access to API Services*. Sem isso o jogo roda em
  **modo memória** (funciona, mas nada é salvo; o Output avisa).
- Recomendado: *Max Players* = 8 (a galeria tem 8 vitrines por servidor).

## Como se joga

| Sistema | Como funciona |
|---|---|
| **Máquinas** | Comum (25 Coins, nível 1), Neon (150, nível 5), Dourada (750, nível 15) e Misteriosa (3.000, nível 30). Chegue perto do botão vermelho e aperte **E** (ou toque). O painel mostra as **chances reais** antes de usar. |
| **Abertura** | O servidor cobra, sorteia e entrega o objeto **antes** da animação. A máquina acende, as cápsulas giram e o objeto aparece no compartimento. **PULAR** adianta a exibição. Lendário e Secreto têm brilho, faixa e anúncio para o servidor. |
| **20 objetos** | Do Copo (Comum) ao Artefato Secreto, cada um com modelo 3D próprio montado com peças do Roblox (sem IDs externos). |
| **Raridades** | Comum (cinza), Incomum (verde), Raro (azul), Épico (roxo), Lendário (dourado), Secreto (vermelho). |
| **Inventário** | Grade com ícones 3D, filtro por raridade, ordem por valor/raridade/nome, busca, 12 por página. Favoritar protege da venda. |
| **Venda** | Valor definido no servidor. Raro ou melhor pede confirmação. "Vender repetidos" vende as cópias extras de Comuns e Incomuns (fica 1 de cada). |
| **Coins** | Começa com 250. Ganha vendendo, em missões, presente diário, conquistas, subida de nível e coletando **moedas perdidas** pelo parque (até 20 por hora): quem fica sem saldo sempre pode voltar a jogar. |
| **Níveis e XP** | XP por descobrir objetos novos, missões, coleções e conquistas. Abrir máquinas dá só 5 XP, com limite de 150 por dia. Cada nível novo paga Coins. |
| **Melhorias** | Capacidade do inventário (40 → 160), velocidade de abertura (4 s → 1,8 s), recompensas de missões (+10% por nível) e vitrines (2 → 6). **Nenhuma muda as chances.** |
| **Livro de coleções** | Os 20 objetos por máquina de origem; os que faltam aparecem como silhuetas. Completar cada parte e a coleção inteira dá Coins, XP e **título** (exibido acima da cabeça). |
| **Galeria de vitrines** | Cada jogador ganha um estande; os objetos expostos aparecem em 3D com placa (nome, raridade, dono). Os outros podem visitar. O objeto exposto continua sendo a mesma cópia do inventário. |
| **Missões** | 3 por dia (1 sempre gratuita: coletar moedas ou passear 10 min) + 15 conquistas permanentes. Presente diário com sequência de 7 dias. |
| **Rankings** | Valor da coleção, descobertas, nível e conquistas: top do servidor e global (cache, atualização periódica) no painel 3D e na interface. |

**Não existe no jogo:** compra de Coins com Robux, apostas, trocas por dinheiro real, saques ou
chances escondidas. O código não tem nenhum produto de Robux.

## Segurança e dados

- **O servidor decide tudo:** sorteio (`Random` do servidor), preços, valores de venda, XP,
  recompensas. O cliente só envia ids e escolhas; valores enviados por ele são ignorados.
- **Validações físicas:** usar máquina exige estar perto dela; coletar moeda exige estar perto da moeda.
- **Operações atômicas:** cada ação valida tudo antes de alterar. Se algo falhar no meio, o perfil é
  restaurado da cópia feita antes da operação.
- **Anti-duplicação:** `requestId` (pedido repetido recebe a mesma resposta sem cobrar de novo),
  trava por jogador, intervalo mínimo entre aberturas e limite de frequência por categoria.
  Inventário em pilhas: vender ou expor nunca cria nem duplica objetos.
- **DataStore com trava de sessão** (`MysteryMachine_Profiles_v1`): só o servidor dono da trava grava.
  Autosave a cada 60 s, salvamento na saída e no desligamento, novas tentativas em falhas.
  **Falha ao carregar nunca grava um perfil vazio por cima**: o jogador é avisado e desconectado.
  Perfis corrompidos são reparados ao carregar.

## Estrutura

```
src/shared  → ReplicatedStorage.Shared
  MachineDefinitions, ItemDefinitions, RarityConfig, EconomyConfig, UpgradeConfig, MissionDefinitions
  Logic/   Odds (sorteio), Levels, ProfileSchema (formato + reparo), ProfileOps (todas as regras), ClientView
  Visual/  ItemModels (20 modelos 3D)      Util/  Format, TimeUtil
src/server  → ServerScriptService.Server
  Main.server.lua
  Core/      Remotes (pasta ReplicatedStorage.Remotes + tratamento de pedidos), RateLimiter
  Services/  PlayerDataService, MachineService, InventoryService, EconomyService, UpgradeService,
             CollectionService (livro de coleções), MissionService, RewardService, LeaderboardService,
             ShowcaseService (galeria), MapService (parque)
src/client  → StarterPlayer.StarterPlayerScripts.Client
  Main.client.lua
  Controllers/ UIController, HUDController, MachineController, InventoryController, CollectionController,
               UpgradeController, MissionController, LeaderboardController, SettingsController
  Util/        Net, Store, UI, Sounds, Signal
tests/ (harness, lógica, servidor + cliente simulados)   tools/build_place.py   docs/
```

- **Remotes** (criados pelo servidor em `ReplicatedStorage.Remotes`): `RequestMachineUse`,
  `InventoryAction`, `UpgradeAction`, `ProgressAction` (RemoteFunction) e `MachineResult`,
  `DataUpdated`, `Notify`, `LeaderboardUpdated` (RemoteEvent).
- **Interfaces:** os controllers criam no `PlayerGui` as telas `MainHUD`, `MachineUI`, `RewardUI`,
  `InventoryUI`, `CollectionUI`, `UpgradeUI`, `MissionUI`, `RankingUI`, `SettingsUI`, `Toasts` e
  `Dialogs`. Cada janela é montada só na primeira vez que abre; só uma janela grande fica aberta
  por vez; tudo é escalado por `UIScale` a partir de 1100×650 (PC, celular e tablet).
- **Sons:** só sons que já vêm com o Roblox (`rbxasset://sounds/...`), em `src/client/Util/Sounds.lua`.

## Adicionar conteúdo

- **Novo objeto:** entrada em `ItemDefinitions` (id novo, nunca reutilize um id), modelo em
  `Visual/ItemModels.Builders`, e o id na `pool` de uma máquina. Os testes conferem que tudo bate.
- **Nova máquina:** entrada em `MachineDefinitions` (preço, nível, cores, pool com chances somando 100).
  O `MapService` cria o modelo e os painéis passam a mostrá-la sozinhos.
- **Preços, chances, XP, recompensas:** só nos arquivos de configuração em `src/shared`.
- A arquitetura já separa regras (`ProfileOps`), dados (`ProfileSchema`, com versão) e visual,
  pensando em mutações cosméticas, eventos temáticos, máquinas especiais, novas vitrines e
  áreas de exploração (há uma área cercada "em breve" no mapa). Nada disso está ativo na V1.0.

## Testes

```bash
pip install lupa
```

```bash
python3 tests/harness.py
```

```bash
python3 tests/check_requires.py
```

O CI (`.github/workflows/ci.yml`) roda os mesmos testes em todo push e gera o `.rbxlx` como artefato.

## Publicação GitHub → Roblox

`.github/workflows/publish.yml` publica **só manualmente** (Actions → Publicar no Roblox → digitar
`PUBLICAR`) e usa segredos com nomes exclusivos deste jogo (`MYSTERY_MACHINE_API_KEY`,
`MYSTERY_MACHINE_UNIVERSE_ID`, `MYSTERY_MACHINE_PLACE_ID`), sem tocar na configuração de outros
jogos. Nenhum ID de experiência ou credencial está no código: crie a experiência no Roblox e
cadastre os segredos você mesmo.

## Etapas do desenvolvimento

| Etapa | Situação |
|---|---|
| 1. Protótipo (máquina, objetos, economia, sorteio seguro, inventário) | ✅ feito e testado (simulado) |
| 2. Coleção inicial (20 objetos, 4 máquinas) | ✅ feito e testado (simulado) |
| 3. Progressão (níveis, XP, desbloqueios, melhorias) | ✅ feito e testado (simulado) |
| 4. Conteúdo (missões, presentes, coleção, vitrines) | ✅ feito e testado (simulado) |
| 5. Mapa (lobby, decoração, identidade visual) | ✅ construído por código; **falta conferir visualmente no Studio** |
| 6. Segurança (salvamento, economia, persistência, exploits) | ✅ testado em simulação; **falta teste com DataStore real** |
| 7. Publicação (experiência e testes em dispositivos) | ⏳ pendente: roteiro em [docs/TESTES.md](docs/TESTES.md) |
