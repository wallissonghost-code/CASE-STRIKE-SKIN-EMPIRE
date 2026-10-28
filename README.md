# CASE STRIKE — Skin Empire

Simulador de abertura de caixas, coleção de skins fictícias, banco de renda passiva e gestão de patrimônio para **Roblox**, escrito em Luau e organizado como projeto **Rojo**.

Versão **0.2**. Tudo o que está liberado é real: o servidor decide saldo, sorteios, propriedade de itens e persistência; o cliente só apresenta e anima.

---

## Como abrir no Roblox Studio

1. Instale o [Rojo](https://rojo.space) (CLI + plugin do Studio).
2. Na pasta do projeto: `rojo serve`
3. No Studio, abra um place vazio e clique em **Connect** no plugin do Rojo.
4. Em *Game Settings → Security*, ative **Enable Studio Access to API Services** para testar o salvamento.
   Sem isso o jogo roda em **modo memória** (avisa no Output e não salva nada).
5. Aperte **Play**. O lobby, a interface e os remotes são criados por código.

Para gerar um arquivo de place: `rojo build -o CaseStrike.rbxlx`.

## Testes automatizados

```bash
pip install lupa
python3 tests/harness.py        # sintaxe + lógica + servidor e cliente simulados
python3 tests/check_requires.py # todo require aponta para um módulo existente
```

O harness executa três camadas:

| Camada | O que roda | Testes |
|---|---|---:|
| Sintaxe | todos os 57 arquivos de `src/` | — |
| Lógica (`tests/spec.lua`) | economia, sorteio, banco, missões, renascimento, integridade | 38 |
| Servidor + cliente reais (`tests/server_smoke.lua`) | `Main.server.lua` e `Main.client.lua` num Roblox simulado (`tests/roblox_mock.lua`) com DataStore em memória e relógio virtual | 29 |

O código de `src/` usa um subconjunto de Luau compatível com o parser Lua (sem anotações de tipo, sem `+=`, sem `continue`) justamente para poder ser testado fora do Studio. Itens que exigem o Studio estão em [`docs/TESTES.md`](docs/TESTES.md).

---

## Estrutura

```
src/
  shared/                 -> ReplicatedStorage.Shared
    Config/               definições configuráveis (preços, pesos, fórmulas, missões...)
    Logic/                regras puras, sem dependência do Roblox (testáveis)
      ProfileOps.lua      TODAS as operações que alteram o perfil (atômicas)
      ProfileSchema.lua   perfil padrão, migração e verificação de integridade
      Probability.lua     tabela de chances, sorteio, % exibidos que somam 100
      BankMath.lua        renda por timestamps, limites offline e de cofre
      Wealth.lua          patrimônio sem dupla contagem
      ClientView.lua      fotografia enviada ao cliente
    Visual/               modelos PROVISÓRIOS gerados por código (skins e caixas)
  server/                 -> ServerScriptService.Server
    Core/                 Remotes (validação, rate limit, deduplicação), Validate, RateLimiter
    Services/             PlayerData, Case, Inventory, Economy, Bank, Upgrade, Collection,
                          Mission, Reward, Progression, Leaderboard, Lobby
  client/                 -> StarterPlayerScripts.Client
    Controllers/          UI, HUD, Shop, Case (roleta), Inventory, Bank, Upgrade, Index,
                          ProgressionPanels (Missões/Presentes/Sorte/Atributos/Renascer),
                          Leaderboard, Lobby
    Util/                 Net (requestId), Store (fotografia), Signal
```

### Remotes (`ReplicatedStorage.Remotes`)

| Remote | Tipo | Ações |
|---|---|---|
| `RequestCaseOpen` | RemoteFunction | `open`, `startAuto`, `stopAuto`, `odds` |
| `InventoryAction` | RemoteFunction | `sell`, `sellBulk`, `favorite`, `equip`, `unequip`, `setFastOpen` |
| `BankAction` | RemoteFunction | `deposit`, `withdraw`, `claim`, `upgrade` |
| `UpgradeAction` | RemoteFunction | `apply` |
| `RequestData` | RemoteFunction | `get` |
| `ProgressionAction` | RemoteFunction | `claimDaily`, `claimLevelReward`, `claimMission`, `claimEventChallenge`, `claimCollection`, `claimAchievement`, `setTitle`, `rebirth` |
| `LeaderboardRequest` | RemoteFunction | `get` |
| `DataUpdated` | RemoteEvent | servidor → cliente: fotografia do perfil |
| `CaseOpenResult` | RemoteEvent | anúncio de drops Lendários/Secretos |

`ProgressionAction` e `LeaderboardRequest` foram adicionados aos remotes da especificação para separar responsabilidades. Toda chamada passa por: formato validado → limite de frequência → deduplicação por `requestId` → `pcall`.

---

## Sistemas

**Caixas.** Seis caixas originais (Urban 25, Tactical 75, Neon 200, Shadow 600, Elite 1.500, Imperial 5.000), 10 skins cada. Abertura ×1/×5/×10 com custo total exibido e confirmação, modo rápido, botão para pular a animação e abertura automática com limite de 150 aberturas ou 20 minutos por sessão, parável a qualquer momento. O servidor sorteia **todos** os resultados antes de cobrar e aplica tudo de uma vez; inventário cheio ou saldo insuficiente recusam o pedido sem alterar nada.

**Probabilidades.** Peso por raridade dividido entre as skins dela. A janela da caixa mostra a chance final de cada skin (pedida ao servidor, já com sorte), arredondada pelo método do maior resto para somar exatamente 100%. Valor esperado ≈ 91% do preço em todas as caixas. Catálogo completo em [`docs/CATALOGO.md`](docs/CATALOGO.md).

**Sorte.** Fontes: 7º dia do presente diário (15 min), missão semanal (25 aberturas), evento ativo e renascimentos. Teto de +25%. Só amplifica Raras+; nada é vendido por Robux.

**Inventário.** Grade paginada (20 por página, cartões reaproveitados), filtros, pesquisa, ordenação, inspeção 3D, favoritar, equipar para exibição (modelos soldados ao personagem, sem ferramentas nem dano), vender, depositar e enviar à oficina. Vender favoritas exige digitar `VENDER`. Capacidade de 500 skins.

**Banco.** Renda = `K × valor^0,82 × multiplicador da raridade`, com teto por skin, eficiência moderada, cofre limitado e no máximo 8 h de produção offline. Calculada por timestamps no servidor, sem loop por skin. Skins depositadas não podem ser vendidas, equipadas nem melhoradas.

**Patrimônio.** `créditos + valor de todas as skins (inventário + banco)`, cada instância uma vez. Créditos pendentes no banco só entram depois do resgate. Valor dos equipamentos é só um indicador.

**Oficina.** Cinco melhorias cosméticas (acabamento, brilho, moldura, inspeção, variante) com custo em créditos + materiais e prévia 3D do resultado garantido antes de confirmar. Nenhuma arrisca a skin.

**Progressão.** XP por descobertas, coleções, missões, melhorias e eventos; fontes repetitivas têm limite diário. Níveis liberam caixas, melhorias de banco e recompensas. Renascimento opcional com tela do que é mantido/reiniciado e confirmação digitada `RENASCER`; mantém Épicas+, favoritas, índice, coleções e conquistas.

**Presentes, missões, eventos.** Presente diário em ciclo de 7 dias pelo relógio do servidor (UTC), recompensas por nível e conquista, 3 diárias + 3 semanais determinísticas por período, desafios de evento com datas reais (Festival das Sombras: 25/10–09/11/2026; Exposição de Inverno: 12/12/2026–06/01/2027).

**Rankings.** Patrimônio, nível, skins únicas, coleções e conquistas. Gravação em OrderedDataStore a cada 2 min só quando o valor muda, leitura do top 20 a cada 2,5 min em cache, mais um ranking ao vivo do servidor.

**Persistência.** Um documento por jogador com trava de sessão via `UpdateAsync` (outro servidor não sobrescreve; trava abandonada expira em 15 min), salvamento automático a cada 60 s, salvamento rápido após operações importantes, gravação ao sair e no `BindToClose`, repetição com espera crescente em falhas, histórico das últimas 60 transações no perfil e verificação de integridade ao carregar. Qualquer erro no meio de uma operação restaura a cópia de segurança do perfil.

**Bloqueado.** PvP, monstros, chefes, tiro, dano, crash/apostas, negociação entre jogadores e itens aleatórios pagos (`Config/FeatureFlags.lua`). O botão Batalha e a arena do lobby mostram "EM BREVE".

---

## Configurando

| Quer mudar... | Arquivo |
|---|---|
| Preço das caixas, skins, nomes | `Config/SkinDefinitions.lua` |
| Pesos e valor por raridade | `Config/RarityConfig.lua` |
| Saldo inicial, venda, limites, abertura automática | `Config/EconomyConfig.lua` |
| Fórmula e melhorias do banco | `Config/BankConfig.lua` |
| Receitas da oficina | `Config/UpgradeRecipes.lua` |
| Missões | `Config/MissionDefinitions.lua` |
| Curva de XP, recompensas, renascimento | `Config/ProgressionConfig.lua` |
| Bônus de sorte | `Config/LuckConfig.lua` |
| Eventos e datas | `Config/EventConfig.lua` |
| Conquistas | `Config/AchievementDefinitions.lua` |

Depois de mexer em valores, rode `python3 tests/harness.py`: há testes que verificam soma de 100%, valor esperado entre 80% e 95% do preço e limites do banco.

---

## Problemas conhecidos e pendências

- **Modelos provisórios.** Skins e caixas são montadas com peças básicas por `Visual/SkinModelFactory.lua` e `Visual/CaseModelFactory.lua` e marcadas com o atributo `PlaceholderModel = true`. Substitua por modelos próprios ou licenciados antes de publicar, mantendo a função `build(def, upgrades)`.
- **Sem sons nem imagens.** Nenhum ID de asset foi inventado; ícones usam emoji. Adicione seus próprios assets quando os tiver.
- **Validado fora do Studio.** Servidor e cliente rodam completos no Roblox simulado, mas o layout visual, o desempenho em celulares fracos e sessões reais com vários jogadores precisam ser conferidos no Studio (checklist em `docs/TESTES.md`).
- **Viewports.** O Índice renderiza 60 prévias 3D estáticas e o inventário 20 por página; em aparelhos muito fracos pode valer trocar por imagens renderizadas.
- **Oficina** lista as 60 skins de maior valor; use o botão Oficina no inventário para as demais.
- O módulo `Services/CollectionService.lua` é do jogo; não confundir com o serviço `CollectionService` do Roblox.
- Eventos têm datas fixas em `EventConfig.lua`; cadastre novos eventos antes que os atuais terminem.
- Itens aleatórios pagos, venda de moeda por Robux e negociação entre jogadores estão desligados. Se forem considerados no futuro, revise as regras atuais da Roblox sobre itens aleatórios pagos, divulgação de probabilidades e restrições por `PolicyService` antes de implementar.
