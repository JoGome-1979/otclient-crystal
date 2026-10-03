> Windows: veja [DISTRIBUICAO.md](DISTRIBUICAO.md) para os presets windows-x86-release, windows-x64-release e Debug, e [AMBIENTE-WINDOWS.md](docs/AMBIENTE-WINDOWS.md) para outra maquina. Os caminhos Windows legados abaixo foram substituidos.

# Compilação na raiz do projeto

Todos os comandos abaixo são executados em D:\otclient-main (Windows) ou /mnt/d/otclient-main (Ubuntu WSL).

| Perfil | Configurar | Compilar |
|---|---|---|
| Windows Release | `cmake --preset windows-release` | `cmake --build build/windows-release -j 10` |
| Windows Debug | `cmake --preset windows-debug` | `cmake --build build/windows-debug -j 10` |
| Linux Release | `cmake --preset linux-release` | `cmake --build build/linux-release -j 10` |
| Linux Debug | `cmake --preset linux-debug` | `cmake --build build/linux-debug -j 10` |
| Android Release | `cmake --preset android-release` | `cmake --build build/android-release -j 10` |
| Android Debug | `cmake --preset android-debug` | `cmake --build build/android-debug -j 10` |
| Linux portátil Release | `cmake --preset linux-portable-release` | `cmake --build build/linux-portable-release -j 10` |
| Linux portátil Debug | `cmake --preset linux-portable-debug` | `cmake --build build/linux-portable-debug -j 10` |
| macOS Release | `cmake --preset macos-release` | `cmake --build build/macos-release -j 10` |
| macOS Debug | `cmake --preset macos-debug` | `cmake --build build/macos-debug -j 10` |

Windows usa o terminal x64 Native Tools do Visual Studio 2022 (toolset v143). Linux e Android usam Ubuntu WSL. macOS precisa de macOS/Xcode; não é compilado por esse WSL. O macOS está configurado para Apple Silicon; para Intel altere os triplets para x64-osx. iOS não foi adicionado: este código não contém a integração necessária de iOS/Xcode.

Use `cmake --list-presets` para listar os perfis disponíveis no sistema atual. O `-j` é minúsculo. Também é possível usar `cmake --build --preset linux-release -j 10`.

## Saídas e files/

- Windows Release: dist/dist-windows/Crystal.exe, sem console.
- Windows Debug: build/windows-debug/bin/Crystal.exe, com console e DLLs de depuração.
- Linux Release: dist/dist-linux/Crystal.
- Linux Debug: build/linux-debug/bin/Crystal.
- APK: build/android-release/Crystal.apk ou build/android-debug/Crystal.apk.
- Linux portátil: dist/linux-portable-Release/client/ ou dist/linux-portable-Debug/client/.

No final de cada build bem-sucedido, files/ é reconstruída com init.lua, data/, modules/ e mods/. Os binários Windows/Linux e o APK Release mais recentes são preservados. Um build Release atualiza o pacote da respectiva plataforma; Debug atualiza recursos e preserva os pacotes Release. Build que falha não deve publicar um APK antigo. O histórico corrente dos executáveis Release fica em build/updater-releases/; o staging Android já existente é android-output/updater/.

Não execute builds de plataformas diferentes ao mesmo tempo: ambos sincronizam a mesma files/. Não use recompile.sh, que apaga a pasta build/. Se apagar build/updater-releases/, o próximo build recupera os binários publicados em files/ ou os executáveis de distribuição disponíveis.

## WSL Linux

O ambiente examinado usa Ubuntu 26.04, usuário anten e GCC/G++ 13. O CMake procura o vcpkg automaticamente em /home/anten/vcpkg. Para outro local, exporte VCPKG_ROOT. No Windows, usa VCPKG_ROOT ou D:/vcpkg.

```bash
cd /mnt/d/otclient-main
cmake --preset linux-release
cmake --build build/linux-release -j 10
```

Dez tarefas podem consumir bastante memória. Se o sistema encerrar o compilador, repita o build com `-j 4`. Compilar diretamente no Ubuntu 26.04 não garante execução em distros mais antigas.

## Android

O preset da raiz empacota o APK com Gradle; o Gradle chama o mesmo CMake nativo da raiz com NDK, sem entrar novamente no empacotador. A etapa recria data.zip a partir dos recursos atuais. Android continua sem vínculo obrigatório com libarchive e não altera as configurações de verificação de assets.

Instale JDK 17 no WSL. Instale as Command-line Tools Linux do Android SDK e depois os componentes abaixo:

```bash
sudo apt update
sudo apt install openjdk-17-jdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" --licenses
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" \
  "platform-tools" "platforms;android-36" "build-tools;35.0.0" \
  "ndk;29.0.13599879" "cmake;3.22.1"
```

Se existir android/local.properties com sdk.dir do Windows, ajuste para o SDK Linux. Os presets usam arm64-v8a por padrão. Para outras arquiteturas:

```bash
cmake --preset android-release -DCRYSTAL_ANDROID_ABIS=arm64-v8a,armeabi-v7a
```

As bibliotecas LuaJIT existentes são reutilizadas. Se estiverem ausentes, prepare luajit-src no commit 1ee778a4e37122d8ca7d5733c590a47dafd6b15c antes de compilar; para ABIs de 32 bits, instale gcc-multilib/g++-multilib.

Release exige o mesmo keystore do APK anterior. Configure RELEASE_KEYSTORE, RELEASE_KEYSTORE_PASSWORD, RELEASE_KEY_ALIAS e RELEASE_KEY_PASSWORD no terminal. O fallback debug.keystore só funciona quando o arquivo existe e corresponde à assinatura anterior. Debug usa a assinatura de depuração gerenciada pelo Gradle e não publica o APK em files/.

O empacotador usa CRYSTAL_ANDROID_JOBS=10. O `-j` controla o Ninja externo; ajuste também o paralelismo interno de Android quando necessário:

```bash
cmake --preset android-release -DCRYSTAL_ANDROID_JOBS=4
cmake --build build/android-release -j 4
```

Antes de publicar um APK novo, incremente versionCode em android/app/build.gradle.kts. O projeto está em versionCode 6; o JSON publicado segue esse valor.

## Linux portátil

Exige Docker disponível dentro do WSL. Os presets usam Ubuntu 22.04/GCC 13, montam o código original somente para leitura e compilam numa cópia em volume Docker separado. Release publica o resultado em files/Crystal; Debug preserva o Release. O script exige glibc no máximo 2.35 e liga o runtime C++ estaticamente.

O alvo é Linux x86-64 com glibc e X11/OpenGL. Isso não cobre automaticamente Alpine/musl, ARM64 ou todas as versões antigas. dependencies.txt, elf-versions.txt e compatibility.txt ficam junto da distribuição. Teste a interface gráfica nas distros que pretende suportar antes de publicar.

## Testes

windows-tests, windows-release-asan e linux-tests são perfis separados com dependências GTest. Debug comum não instala automaticamente as dependências de testes.

Os perfis existentes usam diretórios de cache próprios. Reexecute a configuração antes do primeiro build com estes novos arquivos. Não é necessário apagar os caches existentes.

## Valida��o desta configura��o

A configura��o Windows Release foi validada com MSVC e depend�ncias existentes, incluindo sa�da Crystal.exe e subsistema Windows. Os presets Android e Linux port�til Release/Debug foram configurados no WSL. A sincroniza��o foi testada com arquivos de teste: publica��o Release, preserva��o entre plataformas e Debug, atualiza��o/remo��o de recursos e bloqueio de destinos incorretos.

A compila��o completa dos clientes n�o foi executada. No teste Linux com instala��o do vcpkg desabilitada, faltou STDUUID no cache existente; use os comandos normais acima, que mant�m a instala��o do manifesto habilitada. No WSL ainda faltam JDK/SDK Android e Docker. macOS n�o foi validado neste computador.
