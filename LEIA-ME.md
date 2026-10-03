> Windows: veja [DISTRIBUICAO.md](DISTRIBUICAO.md) para os presets windows-x86-release, windows-x64-release e Debug, e [AMBIENTE-WINDOWS.md](docs/AMBIENTE-WINDOWS.md) para outra maquina. Os caminhos Windows legados abaixo foram substituidos.

# Compilação Crystal pelo mesmo padrão CMake

Este controlador é separado de D:\otclient-main. Ele não exige substituir o CMakeLists.txt nem os presets do cliente. Durante a análise, nenhum arquivo do cliente, da VPS ou do ambiente Ubuntu foi alterado. Quando você executar uma compilação, o projeto naturalmente atualizará suas pastas de distribuição e files/.

Execute dentro da pasta que contém este LEIA-ME.md:

| Resultado | Terminal | Comando |
|---|---|---|
| Windows | x64 Native Tools Command Prompt do VS 2022 | `cmake --workflow --preset windows` |
| Linux para desenvolvimento no Ubuntu atual | Ubuntu WSL | `cmake --workflow --preset linux` |
| APK Android arm64 | Ubuntu WSL | `cmake --workflow --preset android` |
| Linux x86-64 para distribuição entre distros com glibc | Ubuntu WSL com Docker | `cmake --workflow --preset linux-portable` |

O mesmo padrão configura e compila. Windows usa MSVC; Linux usa GCC; no APK, o controlador aciona o Gradle Wrapper, que usa o CMake/NDK do SDK para compilar a biblioteca nativa e monta/assina o APK. CMake sozinho não empacota o código Java/Kotlin em um APK.

## O que foi encontrado no seu computador

- WSL: distribuição chamada Ubuntu, versão 26.04.1, usuário anten.
- CMake 4.2.3 no WSL e 4.4.3 no Windows; ambos suportam workflow presets.
- GCC/G++ 13.4 disponíveis; vcpkg em /home/anten/vcpkg.
- Nenhuma variável VCPKG_ROOT, ANDROID_HOME, ANDROID_NDK_HOME ou JAVA_HOME exportada no shell examinado.
- Java, Docker e SDK Android não estavam disponíveis nos caminhos examinados. Os scripts antigos apontam para /home/crystal e uma distribuição Crystal-Android, que não aparece na lista atual do WSL.
- O Linux já gerado em D:\otclient-main\dist\dist-linux\Crystal é ELF x86-64 e usa X11/OpenGL, glibc, libstdc++ e libgcc compartilhados. Nos símbolos GLIBC examinados, o maior requisito é GLIBC_2.34. Esse dado não garante compatibilidade completa: também há requisitos de GLIBCXX, bibliotecas e driver gráfico.
- O preset windows-release original usa RelWithDebInfo e v145, embora o cache examinado use MSVC 14.44 do VS 2022. Este controlador usa Release e v143 por padrão. O preset linux original também usa RelWithDebInfo; aqui a compilação seleciona Release.
- SyncUpdaterFiles.cmake procura dist-linux/Crystal, mas o projeto gera dist/dist-linux/Crystal. Isso pode retirar o Linux de files/ depois de uma compilação Windows. O controlador recoloca o Linux existente no caminho certo ao concluir uma compilação nativa.
- recompile.sh apaga o conteúdo de build/. Evite esse script quando quiser preservar caches e builds de Windows, Linux e Android.

## Usar agora para Linux

Descompacte esta pasta em um lugar de sua escolha. Para melhor desempenho no WSL, use o sistema de arquivos Linux, por exemplo /home/anten/crystal-build. O código continua em /mnt/d/otclient-main; você continua editando D:\otclient-main.

No PowerShell:

```powershell
wsl -d Ubuntu
```

No WSL, dentro da pasta do controlador:

```bash
cmake --workflow --preset linux
```

Os padrões já correspondem ao ambiente examinado: projeto /mnt/d/otclient-main, vcpkg /home/anten/vcpkg e GCC/G++ 13. O primeiro build pode demorar para preparar dependências. O limite inicial é quatro tarefas paralelas, e unity/IPO estão desabilitados neste controlador para reduzir picos de memória.

Se faltar uma dependência de sistema, prepare o WSL:

```bash
sudo apt update
sudo apt install build-essential gcc-13 g++-13 ninja-build ccache git curl \
  autoconf autoconf-archive automake libtool libtool-bin pkg-config nasm \
  zip unzip tar python3 libx11-dev libxrandr-dev libxi-dev libxcursor-dev \
  libxinerama-dev libgl1-mesa-dev libglu1-mesa-dev libpulse-dev
```

Saídas: artifacts/linux/client/ e artifacts/linux/updater/Crystal. Esse build usa seu Ubuntu 26.04; prefira linux-portable para publicar a outros usuários.

## Windows

Abra o terminal x64 Native Tools do Visual Studio 2022, entre na mesma pasta do controlador e execute:

```bat
cmake --workflow --preset windows
```

O padrão do vcpkg é D:/vcpkg, ou a variável VCPKG_ROOT quando definida. Release usa o subsistema Windows já configurado no projeto, evitando o console. Saídas: artifacts/windows/client/ e artifacts/windows/updater/Crystal.exe.

## Preparar Android neste WSL

Os caminhos do SDK precisam ser Linux. Não use o SDK Windows como se seus executáveis fossem Linux.

1. Instale JDK 17:

```bash
sudo apt update
sudo apt install openjdk-17-jdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
```

2. Baixe o pacote Linux de Command-line Tools no site oficial Android e coloque o conteúdo em ~/Android/Sdk/cmdline-tools/latest/. Deve existir ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager.

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/29.0.13599879"
export VCPKG_ROOT="$HOME/vcpkg"
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" --licenses
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" \
  "platform-tools" "platforms;android-36" "build-tools;35.0.0" \
  "ndk;29.0.13599879" "cmake;3.22.1"
```

3. Confira o keystore usado pelo APK já instalado. O projeto usa RELEASE_KEYSTORE, RELEASE_KEYSTORE_PASSWORD, RELEASE_KEY_ALIAS e RELEASE_KEY_PASSWORD. Configure essas variáveis no terminal, usando a mesma chave do APK anterior. Não gere uma chave nova para tentar atualizar uma instalação assinada com outra chave. O fallback para debug.keystore só funciona se esse arquivo existir e corresponder à assinatura anterior.

4. As bibliotecas LuaJIT existentes serão usadas. Se estiverem ausentes, o controlador usa o script do projeto para compilá-las. Prepare luajit-src, se necessário:

```bash
cd /mnt/d/otclient-main
git clone https://github.com/LuaJIT/LuaJIT.git luajit-src
git -C luajit-src checkout 1ee778a4e37122d8ca7d5733c590a47dafd6b15c
```

Execute o clone somente se luajit-src não existir. Para incluir armeabi-v7a ou x86, instale também gcc-multilib e g++-multilib. O padrão arm64-v8a evita compilar quatro arquiteturas sem necessidade.

5. Dentro da pasta do controlador:

```bash
cmake --workflow --preset android
```

O controlador recria data.zip com os recursos atuais e executa o Gradle Wrapper. A saída é artifacts/android/updater/Crystal.apk junto com android-version.json. Antes de publicar uma nova versão, incremente versionCode em android/app/build.gradle.kts; hoje é 6. O Gradle já gera o JSON correspondente. Se existir android/local.properties com sdk.dir do Windows, ajuste esse arquivo para apontar para o SDK Linux antes de compilar.

## Linux para várias distribuições

linux-portable compila em um container Ubuntu 22.04 com GCC 13. As dependências são compiladas na mesma base e o runtime C++ é ligado estaticamente. A imagem utiliza o PPA Ubuntu Toolchain e CMake 3.31.8; o vcpkg é fixado no builtin-baseline do seu manifesto. Para reprodução bit a bit, também seria necessário fixar os digests da imagem e as versões exatas dos pacotes do sistema.

Instale/configure Docker com integração WSL para a distribuição Ubuntu e verifique:

```bash
docker info
```

Depois, dentro do controlador:

```bash
cmake --workflow --preset linux-portable
```

O código original é montado como somente leitura. A compilação ocorre numa cópia em um volume Docker próprio, preservando o cache entre builds. Esse fluxo não substitui o Linux que você compilou diretamente no Ubuntu 26.04 nem modifica files/ do projeto original.

Saídas em artifacts/linux-portable/:

- client/: executável Crystal e recursos.
- updater/Crystal: executável para publicar na API.
- dependencies.txt e elf-versions.txt: dependências e versões ELF reais.
- compatibility.txt: maior versão GLIBC requerida pelo resultado.

O script rejeita requisitos superiores a glibc 2.35 e runtime C++ compartilhado inesperado. Ele não torna o programa universal: o alvo é Linux x86-64 com glibc e X11/OpenGL disponíveis, incluindo muitas instalações Ubuntu, Debian e Fedora. Alpine com musl, Linux ARM64, máquinas sem os drivers/bibliotecas necessários e todas as versões antigas não estão cobertos. Um AppImage pode facilitar a entrega de dependências adicionais, mas não elimina a exigência da glibc nem a arquitetura do processador.

Antes de publicar, execute o programa em máquinas/VMs representativas das distribuições que você quer suportar. O container de compilação verifica bibliotecas, mas não testa a interface gráfica. O updater Linux do cliente também requer uma revisão separada do reinício e das permissões de execução: sua rotina launchCorrect atual é exclusiva de Windows.

## Ajustar caminhos, ABIs ou paralelismo

Exemplo Android para duas arquiteturas:

```bash
cmake --preset android -DCRYSTAL_ANDROID_ABIS=arm64-v8a,armeabi-v7a -DCRYSTAL_JOBS=4
cmake --workflow --preset android
```

Exemplo de outro caminho de projeto/vcpkg:

```bash
cmake --preset linux -DCRYSTAL_SOURCE_DIR=/caminho/otclient-main \
  -DCRYSTAL_VCPKG_ROOT=/caminho/vcpkg
cmake --workflow --preset linux
```

Os valores ficam no cache separado de cada preset. O CMake no SDK Android permanece em 3.22.1, como exige o Gradle do projeto; o controlador/workflows usa CMake 3.25 ou mais recente. Os builds de diferentes plataformas não devem ser executados ao mesmo tempo, pois o projeto atual sincroniza o mesmo files/.

## Validação desta entrega

Consulte VALIDACAO.md para os testes realmente executados. Nenhum cliente/APK foi compilado durante esta análise e a opção portátil ainda precisa de Docker. A configuração pronta não substitui os componentes ausentes do SDK ou a chave de assinatura.

## Fontes oficiais

- CMake workflow presets: https://cmake.org/cmake/help/v3.31/manual/cmake-presets.7.html
- NDK e CMake/Gradle: https://developer.android.com/ndk/guides/cmake
- AGP 8.12/JDK: https://developer.android.com/build/releases/agp-8-12-0-release-notes
- SDK Command-line Tools: https://developer.android.com/studio
- Docker/WSL: https://docs.docker.com/desktop/features/wsl/
- Compatibilidade entre distribuições: https://docs.appimage.org/reference/best-practices.html
