# Dominion of Eras — como o jogo funciona

Jogo de estratégia em tempo real original, modelado na jogabilidade vista nas capturas de referência
(`reference/picture-*.jpg`). Cada valor abaixo ou vem do que as capturas mostram (indicado pela
imagem) ou é **estimado** (típico do gênero, ajustado com partidas simuladas pela opção `--sim`).
Os mesmos valores estão em `mechanics.json` e em `scripts/defs.gd`.

> Nota: o único programa que havia na pasta era um instalador web (sem regras ou números do jogo de
> referência), e o jogo em si não está instalado neste computador. Por isso quase todos os números são
> estimativas. O registro dessa verificação está em `investigation.cany/`.

## Mapa, câmera e visão
| Valor | Número | Origem |
|---|---|---|
| Mapa | 160 × 160 m, células de caminho de 2 m, cercado por praia e mar | estimado |
| Territórios | 13 (regiões de Voronoi com bordas no chão; os dominados ficam na cor do dono) | bordas e mensagens de controle nas capturas |
| Névoa de guerra | preto = inexplorado, escuro e sem cor = explorado, claro = visível agora | capturas 6–200 |
| Câmera | inclinada, campo de visão 40°, 46° de inclinação, 25–110 m de distância (inicial 68) | estimado |
| Estações | 54 s por mês, começa em junho; dez–fev é inverno (neve no chão, nos telhados e nas árvores, velocidade 11 → 10, −25 % na coleta de comida) | duração do mês derivada dos relógios das capturas 8, 60 e 130; velocidade de inverno da captura 143 |

## Economia
| Valor | Número | Origem |
|---|---|---|
| Recursos iniciais ("Baixo") | Comida 200, Madeira 200, Pedra 100, Ouro 100, Tecnologia 100 | captura 8 |
| Recursos iniciais "Padrão" / "Alto" | ×2 / ×5 | estimado |
| Cidadãos iniciais | 6 | captura 8 |
| Coleta por cidadão (por s) | frutas 0,8 · gado 1,0 · fazenda 0,6 · madeira 0,7 · pedra 0,5 · ouro 0,5 | estimado |
| Carga | 10, entregue no Centro da Cidade ou Armazém mais próximo | estimado |
| Tecnologia | estudiosos na Universidade geram 0,4/s cada (máx. 5) | estimado |
| População | +10 por Centro da Cidade / Casa, limite 200 | estimado |
| Depósitos | frutas 200, gado 150, árvore 100, pedra 400, ouro 400 | estimado |
| Bônus | +5 % de coleta por era, +10 % com a Coroa Econômica | estimado |

## Unidades (a velocidade é o número do painel; × 0,3 = metros por segundo)
| Unidade | Vida | Ataque | Alcance | A cada | Vel. | Armadura | Custo | Tempo | Era | Forte contra |
|---|---|---|---|---|---|---|---|---|---|---|
| Cidadão | 30 | 5 | corpo a corpo | 1,5 s | 11 | 0 | 50 C | 12 s | 1 | — (vida, ataque e velocidade da captura 8) |
| Lanceiro | 60 | 6 | corpo a corpo | 1,5 s | 11 | 1 | 30 C 20 M | 15 s | 1 | cavalaria ×3 |
| Espadachim | 80 | 9 | corpo a corpo | 1,5 s | 10 | 2 | 40 C 30 O | 18 s | 1 | infantaria ×1,5, construções ×1,5 |
| Arqueiro | 45 | 7 | 12 m | 2,0 s | 11 | 0 | 30 M 30 O | 16 s | 1 | infantaria ×1,5 |
| Cavaleiro | 110 | 10 | corpo a corpo | 1,7 s | 16 | 2 | 60 C 50 O | 22 s | 2 | arqueiros e cerco ×2 |
| Catapulta | 120 | 10 | 16 m | 4,0 s | 7 | 3 | 100 M 80 O | 30 s | 3 | construções ×4, área de 2 m |

(C = Comida, M = Madeira, P = Pedra, O = Ouro, T = Tecnologia.) Todos os valores, exceto os do
Cidadão, são estimados. Dano = ataque × (1 + 10 % por era acima da primeira, só soldados) × (1,1 com
a Coroa Militar) × bônus de classe − armadura do alvo, no mínimo 1. Construções têm 1,5 × armadura
contra unidades que não sejam espadachins ou catapultas.

**Atacar ao mover**: soldados enviados com `G` + clique (ou Ctrl + clique direito, ou o botão
"Atacar") lutam contra todo inimigo que encontrarem no caminho e depois seguem até o destino.

## Construções (todas estimadas)
| Construção | Vida | Custo | Tamanho | Tempo | Função |
|---|---|---|---|---|---|
| Centro da Cidade | 1500 | 300 M 200 P | 8 m | 60 s | treina Cidadãos, recebe recursos, +10 população, domina o território, flechas 4 dano / 14 m / 2 s, capturável |
| Casa | 300 | 50 M | 4 m | 20 s | +10 população |
| Fazenda | 200 | 60 M | 6 m | 15 s | comida infinita, 3 fazendeiros |
| Armazém | 400 | 80 M | 4 m | 20 s | ponto de entrega |
| Quartel | 800 | 150 M | 6 m | 35 s | Lanceiro, Espadachim |
| Arquearia | 700 | 150 M | 6 m | 35 s | Arqueiro |
| Estábulo | 800 | 175 M 50 O | 6 m | 40 s | Cavaleiro (era 2) |
| Oficina de Cerco | 800 | 200 M 100 P | 6 m | 45 s | Catapulta (era 3) |
| Universidade | 900 | 150 M 100 P | 6 m | 45 s | 5 estudiosos geram Tecnologia, capturável |
| Torre | 600 | 75 M 100 P | 2 m | 30 s | flechas 8 dano / 16 m / 2 s |

O tempo é para um construtor; mais construtores somam. A fila de treino comporta 5 (Shift + clique
enfileira 5 de uma vez). Construções com menos de metade da vida pegam fogo (só visual).

## Territórios e captura
- Só um Centro da Cidade por território; um Centro concluído domina o território.
- Todas as outras construções precisam ficar dentro de um território seu.
- Infantaria e cavalaria inimigas a até 10 m de um Centro da Cidade ou Universidade sem unidades do
  dono por perto reduzem a lealdade em 2 %/s cada (máx. 8 %/s); ela se recupera 1 %/s. Em 0 % a
  construção muda de dono. Avisos a cada 10 % (mesma mensagem vista na captura 130). Taxas estimadas.

## Eras (o jogo de referência cobre 15 épocas; esta versão tem 5)
| Era | Custo | Tempo |
|---|---|---|
| 1 Idade da Pedra | — | — |
| 2 Idade do Cobre | 300 C 100 O 150 T | 40 s |
| 3 Idade do Bronze | 500 C 250 O 300 T | 60 s |
| 4 Idade do Ferro | 800 C 400 O 500 T | 80 s |
| 5 Era Clássica | 1200 C 600 O 800 T | 100 s |

Avança-se no Centro da Cidade. Cada era: soldados +10 % de vida e ataque, coleta +5 %. Custos estimados.

## Coroas (do primeiro jogador a alcançar cada uma, valem a partida toda; estimado)
- Coroa Militar: 25 abates → +10 % de ataque.
- Coroa Econômica: 3000 recursos coletados → +10 % de coleta.
- Coroa Imperial: chegar à Idade do Bronze → +15 % de velocidade de construção e treino.

## Modo
Escaramuça de conquista contra 1–3 jogadores do computador. Um jogador sai quando fica sem Centro da
Cidade e sem Cidadãos; o último de pé vence. A tela final mostra pontos, era, abates, perdas, unidades
treinadas e recursos coletados de cada jogador.

## Jogadores do computador (estimado)
| | Fácil | Normal | Difícil | Brutal | Insano |
|---|---|---|---|---|---|
| Coleta | ×0,75 | ×1,0 | ×1,1 | ×1,25 | ×1,5 |
| Primeiro ataque | 11 min | 7 min | 5,5 min | 4 min 20 s | 3 min 20 s |
| Primeira onda (soldados) | 5 | 9 | 12 | 14 | 16 |
| Crescimento por onda (máx.) | +2 (14) | +3 (28) | +4 (36) | +5 (46) | +6 (60) |
| Intervalo entre ondas | 210 s | 160 s | 135 s | 110 s | 90 s |
| Cidadãos mantidos | 16 | 24 | 30 | 36 | 44 |
| Decide a cada | 2 s | 1 s | 1 s | 0,5 s | 0,5 s |
| Centros da Cidade desejados | 1 | 2 | 3 | 4 | 5 |
| Torres por cidade | 0 | 1 | 2 | 3 | 4 |
| Responde ao seu exército (treina o que vence suas tropas) | — | sim | sim | sim | sim |
| Reúne o exército antes de marchar | — | sim | sim | sim | sim |
| Cidadãos fogem de ataques | — | sim | sim | sim | sim |
| Recua de lutas perdidas / volta para defender a cidade | — | — | sim | sim | sim |
| Concentra o ataque (alvo fraco e classe certa; catapultas nas torres) | — | — | sim | sim | sim |
| Ataca o rival mais fraco | — | — | sim | sim | sim |
| Cavalaria caça cidadãos; reforça ataques que vão bem | — | — | — | sim | sim |

Comportamento comum a todos os níveis:
- **Economia**: divide os trabalhadores partindo de comida 40 %, madeira 32 %, ouro 14 %, pedra 7 %,
  tecnologia 7 % e ajusta conforme a "lista de compras" (próxima era, próxima construção, soldados):
  falta de um recurso puxa mais gente, sobra puxa menos. Rebalanceia a cada 5–12 s conforme o nível.
  Constrói Fazendas quando a comida natural acaba e (do Normal em diante) Armazéns perto de recursos
  distantes. Conserta construções danificadas.
- **Construção**: Casa antes de atingir o limite; Quartel (50 s), Universidade (110 s), Arquearia
  (170 s), Estábulo, segundo Quartel, Oficina, e assim por diante. Avança de era quando pode pagar e,
  já tendo algum exército, guarda os recursos da próxima era em vez de gastá-los em soldados.
- **Expansão**: escolhe o território livre mais próximo, preferindo os ricos em recursos e longe de
  cidades rivais; reconstrói o Centro se o perder.
- **Defesa**: reage ao que é atacado em casa (não persegue quem ataca seus soldados em campanha).
- Os jogadores do computador enxergam o mapa inteiro.

## Controles
- **Computador**: clique esquerdo seleciona (Shift soma, duplo clique = todos do tipo na tela),
  arrastar desenha a caixa, clique direito move / coleta / constrói / conserta / ataca / define o
  ponto de reunião. WASD, setas ou bordas da tela movem a visão, a roda aproxima, Q/E ou arrastar com o
  botão do meio giram. `G` = atacar ao mover, `M` = todo o exército, `H` = Centro da Cidade,
  `.` = próximo cidadão ocioso, Ctrl+0–9 / 0–9 = grupos, Del remove, Espaço vai ao último alerta,
  `P` pausa, Esc abre o menu. O botão "1x" no topo muda a velocidade do jogo (1x, 1,5x, 2x, 3x).
- **Toque (Android)**: toque para selecionar; toque no chão / árvore / inimigo para ordenar; toque
  duplo = todos do tipo; arrastar com um dedo move a visão; pinça aproxima; o botão de caixa faz o
  arrasto desenhar a caixa de seleção; segurar limpa a seleção ou cancela a construção.

## Fora desta versão
Navios e mar navegável, muralhas, diplomacia, várias civilizações com bônus próprios, épocas 6–15,
heróis, planejador de guerra, sons e música.
