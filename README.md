# Dominion of Eras

Jogo de estratégia em tempo real para Linux e Android, feito em Godot 4.4 (GDScript), inspirado na
jogabilidade de clássicos do gênero. É um jogo **original**: nome, modelos, cores, interface e textos
são próprios e nenhum arquivo de outro jogo é usado (veja `CREDITS.md`).

Colete comida, madeira, pedra, ouro e tecnologia com seus cidadãos, domine territórios com Centros da
Cidade, avance por cinco eras, treine lanceiros, espadachins, arqueiros, cavaleiros e catapultas e
conquiste de 1 a 3 rivais controlados pelo computador, em cinco níveis de dificuldade.
Todas as regras e números estão em `MECHANICS.md`.

## Como rodar
- Pelo editor/linha de comando: `Godot_v4.4.1-stable_linux.x86_64 --path app`
- Versão Linux empacotada: `export/linux/run.sh` (gerada por `export/build_linux.sh`).
  **Depois de alterar os scripts, rode `sh export/build_linux.sh` de novo** para o executável e o
  pacote Arch refletirem as mudanças.

## Opções de linha de comando (depois de `--`)
- `--screenshot <arquivo.png>`: inicia uma partida, desenha 120 quadros, salva a imagem e sai.
  - com `--menu`: imagem do menu principal;
  - com `--showcase` (`--winter`, `--fight`, `--close`, `--look x,z,zoom`): todas as construções e unidades lado a lado.
- `--self-test <arquivo.json>`: joga um roteiro (mover, coletar, treinar, construir, lutar, atacar ao
  mover, avançar de era, conferir o painel e os rivais) e grava o resultado.
- `--sim <segundos>`: quatro jogadores do computador jogam sozinhos e imprimem o estado a cada minuto.
  `--diff Hard` define o nível de todos; `--diffs Easy,Normal,Hard,Insane` define um nível por jogador;
  `--seed N` muda o mapa.

## Organização dos scripts (`scripts/`)
| Arquivo | Papel |
|---|---|
| `defs.gd` | Todos os números e textos de regras (unidades, construções, eras, dificuldades). |
| `game.gd` | A partida: mapa, territórios, névoa, estações, coroas, captura, vitória, terreno e luz. |
| `unit.gd`, `building.gd`, `resnode.gd`, `entity.gd` | Unidades, construções e recursos. |
| `ai.gd` | Os rivais do computador. |
| `controls.gd`, `cam.gd` | Mouse, teclado, toque e câmera. |
| `hud.gd`, `icons.gd` | Interface: barra de recursos, painéis, minimapa e ícones desenhados em código. |
| `meshes.gd`, `fx.gd` | Modelos 3D montados em código e efeitos (fumaça, fogo, poeira). |
| `main.gd` | Menu principal, início de partidas e as opções acima. |

## Gerar para Linux (Arch) e Android
Veja `export/BUILD.md`.
