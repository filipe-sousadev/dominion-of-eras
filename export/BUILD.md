# Building Dominion of Eras

## Linux (Arch)
Already built:
- `linux/run.sh` runs the game (the folder `linux/` can be copied anywhere).
- `arch/dominion-of-eras-1.0-1-x86_64.pkg.tar.zst` installs it system-wide:
  `sudo pacman -U arch/dominion-of-eras-1.0-1-x86_64.pkg.tar.zst`, then start "Dominion of Eras"
  from the menu or run `dominion-of-eras`.

Rebuild after changes: `sh build_linux.sh`.

## Android (APK)
O projeto está pronto para Android: controles por toque, tela em paisagem, botão "voltar" abre o menu
de pausa, margens para o entalhe da tela, ícones do aplicativo (`android_icons/`), cenário mais leve
em celulares, preset de exportação `Android` (pacote `org.dominionoferas.game`, arm64).

### Pelo GitHub (recomendado)
A receita de compilação está em `export/github-android.yml` e o `.gitignore` já está na pasta `app/`.
Use a pasta `app/` como raiz do repositório e copie a receita para o lugar que o GitHub lê:

    cd app
    mkdir -p .github/workflows
    cp export/github-android.yml .github/workflows/android.yml
    git init -b main
    git add .
    git commit -m "Dominion of Eras"
    git remote add origin git@github.com:SEU_USUARIO/dominion-of-eras.git
    git push -u origin main

A cada push na `main` o GitHub compila o APK e o publica em **Releases** (leva alguns minutos; acompanhe
na aba **Actions**). No celular, abra a página de Releases do repositório, baixe `dominion-of-eras.apk`
e instale (é preciso permitir "instalar apps desconhecidos").

Assinatura: sem configuração, cada compilação usa uma chave nova, então é preciso desinstalar a versão
anterior antes de instalar a seguinte. Para atualizar por cima, crie uma chave uma vez e guarde nos
Secrets do repositório (Settings → Secrets and variables → Actions):

    keytool -genkeypair -keystore dominion.keystore -alias dominion -keyalg RSA -keysize 2048 -validity 10000
    base64 -w0 dominion.keystore   # cole em ANDROID_KEYSTORE_BASE64

e defina também `ANDROID_KEYSTORE_USER` (o alias) e `ANDROID_KEYSTORE_PASSWORD`.

### No seu computador
1. Modelos de exportação do Godot 4.4.1 (Editor → Gerenciar Modelos de Exportação → Baixar).
2. Android SDK com `platform-tools`, `build-tools;34.0.0` e `platforms;android-34`, e JDK 17
   (`sudo pacman -S jdk17-openjdk`; `yay -S android-sdk-cmdline-tools-latest`).
3. No editor: Configurações do Editor → Exportar → Android: caminho do Android SDK e do Java SDK.
4. `Godot_v4.4.1-stable_linux.x86_64 --headless --path .. --export-debug "Android" export/android/dominion-of-eras.apk`
5. `adb install -r android/dominion-of-eras.apk` (celular com depuração USB ligada).
