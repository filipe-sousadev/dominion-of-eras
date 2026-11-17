# O que mudou (trabalho do Claude, 17/11/2026)

Os scripts anteriores estão guardados em `EE2/app_backup_original/` (fora do projeto Godot, para não
duplicar classes). Para voltar atrás, copie-os de volta para `app/scripts/`.

## 1. Tradução (português do Brasil)
Menus, painéis, mensagens, dicas, nomes de unidades, construções, eras, recursos, meses, territórios e
coroas. Documentos `README.md`, `MECHANICS.md` e `CREDITS.md` também em português.

## 2. Rivais mais inteligentes, 5 dificuldades (`scripts/ai.gd`, `scripts/defs.gd`)
Fácil, Normal, Difícil, Brutal, Insano. Além de coletar mais rápido, cada nível liga táticas:
- treina o que vence o seu exército (lanceiros contra cavalaria, cavalaria contra arqueiros etc.);
- reúne o exército antes de marchar e avança atacando o que encontra (não chega mais em fila);
- recua de lutas perdidas e chama o exército de volta se a cidade for atacada (Difícil+);
- concentra o ataque no alvo certo; catapultas miram torres (Difícil+);
- ataca o rival mais fraco (Difícil+);
- cavalaria caça seus cidadãos longe das torres e reforça ataques que vão bem (Brutal+);
- economia por "lista de compras", armazéns perto de recursos distantes, consertos, torres,
  expansão para territórios ricos e reserva de recursos para a próxima era.
A tabela completa está em `MECHANICS.md`.

## 3. Interface (`scripts/hud.gd`, `scripts/icons.gd`, `scripts/main.gd`)
- Barra de recursos no topo com ícones; população fica vermelha no limite; barra de progresso da era.
- Botões de comando com ícones e custo (vermelho quando falta recurso) e painel de ajuda ao passar o
  mouse (custo, descrição, atributos, bônus).
- Painel de seleção com retrato, vida, atributos, "forte contra", fila de treino em ícones e grade de
  tipos na seleção múltipla.
- Placar de jogadores (era, territórios, pontos), ícones de coroas, alerta vermelho nas bordas ao ser
  atacado, barras de vida/treino/construção sobre as unidades.
- Novos comandos: atacar ao mover (`G`, Ctrl + clique direito ou botão), selecionar todo o exército
  (`M`), Shift + clique treina 5, velocidade do jogo (1x–3x), tela "Como Jogar", demolir construção.
- Menu principal novo (fundo pintado, descrição da dificuldade, recursos iniciais) e tela final com
  estatísticas de todos os jogadores.

## 4. Gráficos (`scripts/meshes.gd`, `scripts/fx.gd`, `scripts/game.gd`, `scripts/unit.gd`, `scripts/building.gd`)
- Todos os modelos refeitos com mais detalhe; cada modelo virou uma única malha (mais leve que antes).
- Pessoas e cavalos com pernas e braços animados (andar, golpear, trabalhar); catapulta com braço que dispara.
- Terreno novo (variação de grama, terra, praia e mar animado em volta do mapa), bordas de território
  mais finas, grama, flores e pedrinhas espalhadas, vegetação que balança ao vento.
- Neve no chão, nos telhados e nas árvores no inverno, com luz mais fria.
- Fumaça nas chaminés, fogo em construções danificadas, andaimes na obra, poeira e ruínas ao desabar,
  projéteis em arco, soldados caídos ficam no chão por alguns segundos.
- Sol com sombras voltadas para a câmera, luz de preenchimento, antisserrilhado 4x.

## Como testar
- Direto pelo Godot: `Godot_v4.4.1-stable_linux.x86_64 --path app`
- Versão Linux: `export/linux/run.sh` — o arquivo `dominion-of-eras.pck` já foi atualizado.
- **O pacote Arch (`export/arch/*.pkg.tar.zst`) ainda é o antigo.** Para refazê-lo: `sh export/build_linux.sh`.
- Imagens novas em `app/shots/novo_*.png`; resultado do autoteste (9 de 9) em `app/shots/selftest_novo.json`.

## O que não foi feito
- Sons e música (o jogo continua mudo).
- O APK Android não foi gerado (continua dependendo do SDK, ver `export/BUILD.md`). O código novo usa
  só recursos do renderizador de compatibilidade, mas não foi testado em um aparelho.
- Os números de unidades e construções continuam sendo estimativas (o jogo de referência não está instalado).
- A dificuldade foi ajustada com partidas computador × computador; o equilíbrio contra uma pessoa
  ainda precisa do seu teste.
