# MUTANT FACTORY

Jogo de Roblox de criaturas mutantes: compre criaturas na esteira da fábrica ou abra ovos,
monte sua base para gerar moedas, **roube criaturas das bases dos outros** e proteja a sua.
Evolução do protótipo *Mutant Factory V0.1* (6 bases, ovo, mutações e renda por segundo),
reescrito com economia validada no servidor, salvamento com trava de sessão e testes automáticos.

> Situação: o jogo roda inteiro num ambiente Roblox **simulado** (servidor e interface reais, 62 testes
> passando). Ele **ainda não foi aberto no Roblox Studio nem publicado**. Siga o roteiro de
> [docs/TESTES.md](docs/TESTES.md) no Studio antes de publicar.

## Abrir no Roblox Studio

- **Sem ferramentas:** abra `MutantFactory.rbxlx` (File → Open) e clique em Play. O mapa é construído por código ao iniciar.
- **Com Rojo:** `rojo serve` (usa `default.project.json`).
- Para salvar progresso no Studio: publique como experiência de teste e ative *Game Settings → Security → Enable Studio Access to API Services*. Sem isso o jogo roda em **modo memória** (nada é salvo; o Output avisa).
- Para testar o roubo: *Test → Clients and Servers* com 2 ou 3 jogadores.

## Como se joga

| Sistema | Como funciona |
|---|---|
| **Esteira da fábrica** | A cada ~3,5 s sai uma criatura sorteada pelo servidor. Chegue perto e aperte **E** para comprar (quem chegar primeiro leva). Preço = preço da espécie × multiplicador da mutação. |
| **Ovos** | Quiosques Básico ($300), Raro ($10 mil) e Lendário ($100 mil, depois do 1º renascimento). As chances aparecem no painel já com sorte e evento. |
| **Base** | 6 bases por servidor. As criaturas ficam em pedestais (8 no início, até 20) e guardam moedas até o limite do cofre (30 min, até 4 h com melhorias), **inclusive com você offline**. Colete no terminal amarelo ou no botão COLETAR estando na base. |
| **Roubo** | Entre numa base **sem escudo**, segure **E** em uma criatura e leve até a **sua** base em até 45 s (você anda mais devagar). Se o dono **encostar** em você, ela volta. Sem dano e sem combate. A criatura roubada fica protegida por 3 min. |
| **Escudo** | Terminal azul ou botão TRAVAR BASE (dentro da sua base): 60 s (+10 s por melhoria). Lasers na entrada e visitantes são levados para fora; quem estava carregando uma criatura sua dentro da base devolve na hora. Ao entrar no jogo você ganha 2 min de proteção. |
| **Mutações** | Normal ×1, Dourada ×2, Diamante ×4, Radioativa ×6, Vazio ×10, Arco-íris ×20 (renda e valor). |
| **16 espécies** | De Gosminha (Comum, $1/s) a Núcleo Primordial (Mítica, $6.500/s), em 6 raridades. Todas montadas com peças do próprio Roblox: nenhum modelo, textura ou ID externo. |
| **Melhorias** | Mais pedestais, cofre maior, escudo reforçado e tênis turbo (velocidade). |
| **Índice** | 96 combinações espécie × mutação, com 7 marcos de recompensa. |
| **Missões e presentes** | 3 missões por dia (iguais para todos) e presente diário com sequência de 7 dias. As recompensas em moedas crescem com a sua renda. |
| **Renascer** | Troca moedas e criaturas por renda ×1,5, ×2, ×2,5… e +5% de sorte por renascimento (até +50%). Índice, melhorias e poções ficam. Pede a frase RENASCER. |
| **Eventos** | Agenda fixa (UTC): a cada 30 min, 6 min de evento: Chuva Dourada, Hora da Sorte, Tempestade Radioativa, Renda em Dobro, Eclipse do Vazio, Esteira Turbo e Aurora Arco-íris. |
| **Poções** | Sorte (+25%), Renda (×1,5) e Velocidade (+6), ganhas em missões, presentes e marcos ou compradas com **moedas do jogo**. |
| **Ranking** | Patrimônio, renda, roubos e defesas dos jogadores do servidor, e leaderstats (Moedas, Renda, Roubos). |

**Não existe no jogo:** compra de sorte, poções ou moedas com Robux; apostas; trocas por dinheiro real.
O código não tem nenhum produto de Robux.

## Segurança e dados

- **O servidor decide tudo:** sorteios, preços, renda, posições. O cliente só manda ids e escolhas; valores enviados por ele são ignorados.
- **Dentro da base de verdade:** coletar e travar exigem o personagem dentro da própria base. O roubo exige estar perto da criatura e entregar dentro da sua base.
- **Operações atômicas:** cada ação valida tudo antes de alterar e, se algo falhar no meio, o perfil é restaurado. O roubo altera os dois perfis de uma vez (ou nenhum) e salva os dois logo depois.
- **Proteções:** `requestId` evita cobrança dupla em pedidos repetidos, e há limite de frequência por categoria.
- **DataStore com trava de sessão** (`MutantFactory_Profiles_v1`): um servidor só grava se for o dono da trava. Há salvamento automático a cada 60 s e na saída/desligamento, novas tentativas em caso de falha e reparo de perfis corrompidos.
- **Renda por horário:** sem laço por criatura. Relógio voltando no tempo não gera moedas; poções e eventos de renda contam só no período em que estavam ativos.

## Estrutura

```
src/shared/Config     GameConfig (conteúdo e balanceamento), ProgressConfig, EventConfig, MapConfig
src/shared/Logic      Odds, Income, ProfileSchema, ProfileOps (todas as operações), ClientView
src/shared/Visual     CreatureModel (criaturas feitas de peças)
src/server/Core       Remotes (despacho, requestId, limites), RateLimiter, Validate
src/server/Services   PlayerData, Map, Base, Conveyor, Steal, Event, Action
src/client            HUD, Ovos/Poções, Base, Índice, Missões/Presentes/Renascer/Ranking/Ajustes, Mundo
tests/                spec.lua (lógica), server_smoke.lua (servidor + cliente simulados), roblox_mock.lua
tools/build_place.py  gera MutantFactory.rbxlx
```

Todo o balanceamento fica em `src/shared/Config/GameConfig.lua`.

## Testes

```
pip install lupa
python3 tests/harness.py        # sintaxe + 30 testes de lógica + 32 de servidor/cliente simulados
python3 tests/check_requires.py # todo require aponta para um módulo existente
python3 tools/build_place.py    # gera MutantFactory.rbxlx
```

O CI (`.github/workflows/ci.yml`) roda tudo isso a cada push e anexa o `.rbxlx` como artefato.

## Publicar no Roblox pelo GitHub

O workflow `.github/workflows/publish.yml` é manual: *Actions → Publicar no Roblox → Run workflow* e digitar `PUBLICAR`.
Ele roda os testes e envia o place pela API Open Cloud.
Configure no repositório os secrets `ROBLOX_API_KEY` (permissão *universe-places: Write* só para este jogo),
`ROBLOX_UNIVERSE_ID` e `ROBLOX_PLACE_ID`.

## Limitações conhecidas

- Máximo de 6 jogadores por servidor (uma base cada). Configure *Max Players = 6* nas configurações do jogo.
- A esteira é movida pelo servidor a cada quadro; com muito atraso de rede o movimento pode parecer menos suave.
- Não há sons: nenhum ID de áudio foi inventado. Adicione os seus se quiser.
