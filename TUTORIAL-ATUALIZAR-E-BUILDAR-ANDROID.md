# Tutorial: atualizar arquivos, empacotar `data.zip` e compilar o Crystal Android

Este tutorial considera a instalação que já está funcionando neste computador:

- código editado no Windows: `D:\otclient-main`;
- código usado na compilação WSL: `/home/crystal/otclient-main`;
- distribuição WSL: `Crystal-Android`;
- Android SDK do Windows: `D:\Android\Sdk`;
- pacote Android: `com.github.otclient`;
- APK final: `Crystal.apk`.

> Execute cada bloco somente no terminal indicado. Comandos de **PowerShell** não devem ser executados no WSL e comandos de **WSL** não devem ser executados no PowerShell.

## 1. Editar o cliente no Windows

Edite normalmente os arquivos dentro de `D:\otclient-main`.

Exemplo: o nome grande exibido atrás da janela de login fica em:

```text
D:\otclient-main\modules\client_bottommenu\bottommenu.otui
```

O texto e o tamanho são controlados por:

```otui
text: Crystal MMORPG
ttf-font-size: 90
```

Salve o arquivo antes de continuar.

## 2. Abrir o WSL

No **PowerShell**, execute:

```powershell
wsl -d Crystal-Android
```

O prompt deverá ficar parecido com:

```text
crystal@DESKTOP:~$
```

## 3. Configurar o ambiente da compilação

No **WSL**, copie e execute o bloco inteiro:

```bash
export ANDROID_HOME=/home/crystal/android-sdk
export ANDROID_SDK_ROOT=/home/crystal/android-sdk
export ANDROID_NDK_HOME=/home/crystal/android-sdk/ndk/29.0.13599879
export VCPKG_ROOT=/home/crystal/vcpkg
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

cd /home/crystal/otclient-main
```

Essas variáveis valem apenas para o terminal WSL atual. Se fechar o terminal, execute o bloco novamente na próxima compilação.

## 4. Criar um backup antes de copiar as alterações

No **WSL**, execute:

```bash
cd /home/crystal/otclient-main

BACKUP_DIR="backups/$(date +%Y%m%d-%H%M%S)-before-android-build"
mkdir -p "$BACKUP_DIR"

cp -a init.lua otclientrc.lua config.ini cacert.pem data mods modules "$BACKUP_DIR"/
cp -a android/app/src/main/assets/data.zip "$BACKUP_DIR/data.zip"

echo "Backup criado em: /home/crystal/otclient-main/$BACKUP_DIR"
```

## 5. Copiar os arquivos editáveis do Windows para o WSL

No **WSL**, execute:

```bash
cd /home/crystal/otclient-main

cp -a /mnt/d/otclient-main/data/. data/
cp -a /mnt/d/otclient-main/mods/. mods/
cp -a /mnt/d/otclient-main/modules/. modules/
cp /mnt/d/otclient-main/init.lua init.lua
cp /mnt/d/otclient-main/otclientrc.lua otclientrc.lua
cp /mnt/d/otclient-main/config.ini config.ini
cp /mnt/d/otclient-main/cacert.pem cacert.pem
```

Esse bloco sincroniza todos os arquivos que entram no `data.zip`. Portanto, ele também inclui a alteração em `modules/client_bottommenu/bottommenu.otui`.

Se você também alterou código nativo, arquivos Gradle ou arquivos Android, copie as pastas correspondentes:

```bash
cd /home/crystal/otclient-main

cp -a /mnt/d/otclient-main/src/. src/
cp -a /mnt/d/otclient-main/android/. android/
cp /mnt/d/otclient-main/CMakeLists.txt CMakeLists.txt
```

> Não use o segundo bloco quando tiver alterações experimentais importantes somente no WSL. Ele substitui arquivos de mesmo nome pela versão presente no Windows.

## 6. Recriar completamente o `data.zip`

No **WSL**, execute:

```bash
cd /home/crystal/otclient-main

rm -f android/app/src/main/assets/data.zip
mkdir -p android/app/src/main/assets

zip -r android/app/src/main/assets/data.zip \
  data \
  mods \
  modules \
  init.lua \
  otclientrc.lua \
  config.ini \
  cacert.pem
```

Esse comando recria o pacote do zero. Isso evita manter dentro do APK arquivos antigos que já foram removidos do projeto.

Confira se o pacote foi criado:

```bash
ls -lh android/app/src/main/assets/data.zip
unzip -t android/app/src/main/assets/data.zip
```

O último comando deve terminar com uma mensagem semelhante a `No errors detected`.

Para confirmar uma alteração específica, por exemplo o texto do menu inferior:

```bash
unzip -p android/app/src/main/assets/data.zip \
  modules/client_bottommenu/bottommenu.otui \
  | grep -n -E "text:|ttf-font-size"
```

## 7. Compilar o APK Debug

Ainda no **WSL**, execute:

```bash
export ANDROID_HOME=/home/crystal/android-sdk
export ANDROID_SDK_ROOT=/home/crystal/android-sdk
export ANDROID_NDK_HOME=/home/crystal/android-sdk/ndk/29.0.13599879
export VCPKG_ROOT=/home/crystal/vcpkg
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

cd /home/crystal/otclient-main/android
chmod +x gradlew
./gradlew assembleDebug -Potclient.android.abis=arm64-v8a
```

Espere aparecer:

```text
BUILD SUCCESSFUL
```

O APK será gerado em:

```text
/home/crystal/otclient-main/android/app/build/outputs/apk/debug/Crystal.apk
```

## 8. Copiar o APK para o Windows

No **WSL**, execute:

```bash
mkdir -p /mnt/d/otclient-main/android-output

cp /home/crystal/otclient-main/android/app/build/outputs/apk/debug/Crystal.apk \
   /mnt/d/otclient-main/android-output/Crystal.apk

sha256sum /mnt/d/otclient-main/android-output/Crystal.apk
ls -lh /mnt/d/otclient-main/android-output/Crystal.apk
```

No Windows, o arquivo ficará em:

```text
D:\otclient-main\android-output\Crystal.apk
```

## 9. Instalar no celular usando o PowerShell

Saia do WSL com:

```bash
exit
```

Conecte o celular por USB, habilite a depuração USB e, no **PowerShell**, confira a conexão:

```powershell
& "D:\Android\Sdk\platform-tools\adb.exe" devices -l
```

O aparelho precisa aparecer com o estado `device`. Se aparecer `unauthorized`, desbloqueie o celular e aceite a autorização de depuração USB.

Instale mantendo os dados e preferências existentes:

```powershell
& "D:\Android\Sdk\platform-tools\adb.exe" install -r "D:\otclient-main\android-output\Crystal.apk"
```

O resultado esperado é:

```text
Success
```

## 10. Quando limpar os dados antigos

Use esta etapa quando alterar valores padrão, escala da interface ou quando o cliente continuar usando arquivos antigos. Ela apaga somente os dados locais do Crystal, incluindo email salvo, preferências e configurações do cliente.

No **PowerShell**:

```powershell
& "D:\Android\Sdk\platform-tools\adb.exe" shell pm clear com.github.otclient
```

Depois abra o Crystal pelo ícone ou execute:

```powershell
& "D:\Android\Sdk\platform-tools\adb.exe" shell monkey `
  -p com.github.otclient `
  -c android.intent.category.LAUNCHER 1
```

## 11. Sequência rápida para as próximas alterações

Depois que o ambiente estiver pronto, este é o fluxo normal.

No **PowerShell**:

```powershell
wsl -d Crystal-Android
```

No **WSL**:

```bash
export ANDROID_HOME=/home/crystal/android-sdk
export ANDROID_SDK_ROOT=/home/crystal/android-sdk
export ANDROID_NDK_HOME=/home/crystal/android-sdk/ndk/29.0.13599879
export VCPKG_ROOT=/home/crystal/vcpkg
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

cd /home/crystal/otclient-main

BACKUP_DIR="backups/$(date +%Y%m%d-%H%M%S)-before-android-build"
mkdir -p "$BACKUP_DIR"
cp -a init.lua otclientrc.lua config.ini cacert.pem data mods modules "$BACKUP_DIR"/
cp -a android/app/src/main/assets/data.zip "$BACKUP_DIR/data.zip"

cp -a /mnt/d/otclient-main/data/. data/
cp -a /mnt/d/otclient-main/mods/. mods/
cp -a /mnt/d/otclient-main/modules/. modules/
cp /mnt/d/otclient-main/init.lua init.lua
cp /mnt/d/otclient-main/otclientrc.lua otclientrc.lua
cp /mnt/d/otclient-main/config.ini config.ini
cp /mnt/d/otclient-main/cacert.pem cacert.pem

rm -f android/app/src/main/assets/data.zip
mkdir -p android/app/src/main/assets
zip -r android/app/src/main/assets/data.zip data mods modules init.lua otclientrc.lua config.ini cacert.pem
unzip -t android/app/src/main/assets/data.zip

cd android
./gradlew assembleDebug -Potclient.android.abis=arm64-v8a

mkdir -p /mnt/d/otclient-main/android-output
cp app/build/outputs/apk/debug/Crystal.apk /mnt/d/otclient-main/android-output/Crystal.apk
sha256sum /mnt/d/otclient-main/android-output/Crystal.apk
```

Depois, no **PowerShell**:

```powershell
& "D:\Android\Sdk\platform-tools\adb.exe" devices -l
& "D:\Android\Sdk\platform-tools\adb.exe" install -r "D:\otclient-main\android-output\Crystal.apk"
```

## 12. Diagnóstico de erros

### O Gradle terminou com erro

No **WSL**, gere informações detalhadas:

```bash
cd /home/crystal/otclient-main/android
./gradlew assembleDebug -Potclient.android.abis=arm64-v8a --stacktrace
```

### O APK abre e fecha

No **PowerShell**:

```powershell
$adb = "D:\Android\Sdk\platform-tools\adb.exe"
& $adb logcat -c
& $adb shell monkey -p com.github.otclient -c android.intent.category.LAUNCHER 1
Start-Sleep -Seconds 10
& $adb logcat -d | Select-String -Pattern "OTClientMobile|FATAL EXCEPTION|Fatal signal|Lua|ERROR"
```

### A alteração não apareceu no celular

Confirme primeiro que ela está dentro do pacote no WSL:

```bash
cd /home/crystal/otclient-main
unzip -l android/app/src/main/assets/data.zip | grep bottommenu.otui
unzip -p android/app/src/main/assets/data.zip modules/client_bottommenu/bottommenu.otui | grep -n "text:"
```

Depois confira se recompilou, reinstalou o APK novo e, se a alteração envolver configurações padrão, execute `pm clear com.github.otclient` conforme a etapa 10.

### O ADB não encontra o celular

No **PowerShell**:

```powershell
$adb = "D:\Android\Sdk\platform-tools\adb.exe"
& $adb kill-server
& $adb start-server
& $adb devices -l
```

Troque o cabo ou a porta USB se a lista continuar vazia.

## 13. Build Release

Para gerar uma versão Release local, no **WSL**:

```bash
cd /home/crystal/otclient-main/android
./gradlew assembleRelease -Potclient.android.abis=arm64-v8a
```

O projeto nomeia o arquivo como `Crystal.apk`. Verifique o caminho com:

```bash
find app/build/outputs/apk/release -maxdepth 1 -type f -name '*.apk' -ls
```

> O Release atual pode usar a chave de depuração como fallback. Para publicar na Google Play, crie e proteja uma chave de assinatura própria; não publique usando a chave de depuração.
