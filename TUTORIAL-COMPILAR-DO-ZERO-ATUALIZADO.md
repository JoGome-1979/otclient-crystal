# Crystal Client: instalação, compilação e instalador do zero

Este guia recria o ambiente em um Windows 11 recém-formatado. Os comandos não dependem de uma letra de disco específica.

## Repositórios oficiais usados

- Cliente base OTClient Redemption: <https://github.com/opentibiabr/otclient>
- Crystal Server 15.25: <https://github.com/zimbadev/crystalserver>
- AAC do Crystal Server: <https://github.com/jprzimba/crystalserver-aac>
- vcpkg: <https://github.com/microsoft/vcpkg>
- Inno Setup: <https://jrsoftware.org/isinfo.php>

> **Importante:** o repositório público do cliente não contém nossas personalizações, ícone, empacotador e instalador. Antes de formatar, guarde uma cópia portátil da pasta personalizada conforme a seção seguinte.

## 1. Antes de formatar: criar o backup portátil personalizado

Abra o PowerShell e indique onde o projeto está instalado atualmente:

```powershell
$CLIENTE_ATUAL = "D:\otclient-main"
$BACKUP_DESTINO = Join-Path ([Environment]::GetFolderPath('Desktop')) "CrystalClient-Fonte-Personalizado.zip"

tar.exe -a -c -f $BACKUP_DESTINO `
  --exclude=build `
  --exclude=Release `
  --exclude=dist `
  --exclude=backups `
  -C $CLIENTE_ATUAL .

Get-Item $BACKUP_DESTINO
Get-FileHash $BACKUP_DESTINO -Algorithm SHA256
```

Copie o ZIP e o SHA-256 exibido para um HD externo, pendrive ou armazenamento em nuvem.

## 2. Depois de formatar: escolher a pasta de trabalho

O exemplo usa uma pasta dentro dos Documentos do usuário. Para usar outro disco, altere somente `$OT_BASE`.

```powershell
$OT_BASE = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "CrystalOT"
$CLIENT_DIR = Join-Path $OT_BASE "otclient-main"
$SERVER_DIR = Join-Path $OT_BASE "crystalserver"
$VCPKG_DIR = Join-Path $OT_BASE "vcpkg"

New-Item -ItemType Directory -Path $OT_BASE -Force
```

Exemplo opcional para outro disco:

```powershell
$OT_BASE = "E:\CrystalOT"
```

Depois de mudar `$OT_BASE`, execute novamente as três linhas que definem `$CLIENT_DIR`, `$SERVER_DIR` e `$VCPKG_DIR`.

## 3. Instalar Git, CMake, Visual Studio 2026 e Inno Setup

Abra o **PowerShell como administrador** e execute:

```powershell
winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
winget install --id Kitware.CMake -e --accept-source-agreements --accept-package-agreements
winget install --id JRSoftware.InnoSetup -e --accept-source-agreements --accept-package-agreements

winget install --id Microsoft.VisualStudio.Community -e `
  --accept-source-agreements `
  --accept-package-agreements `
  --override "--wait --passive --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended --lang en-US"
```

Reinicie o Windows depois da instalação do Visual Studio. Em seguida, confira:

```powershell
git --version
cmake --version
winget list --id Microsoft.VisualStudio.Community -e
winget list --id JRSoftware.InnoSetup -e
```

Se o Visual Studio Installer mostrar componentes opcionais, confirme:

- Desenvolvimento para desktop com C++.
- MSVC x64/x86 mais recente.
- CMake para Windows.
- Windows 11 SDK.
- Pacote de idioma inglês.

Não instale o componente vcpkg interno do Visual Studio; usaremos uma cópia independente.

## 4. Instalar o vcpkg em qualquer unidade

Abra um PowerShell normal e redefina as variáveis caso tenha reiniciado:

```powershell
$OT_BASE = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "CrystalOT"
$CLIENT_DIR = Join-Path $OT_BASE "otclient-main"
$SERVER_DIR = Join-Path $OT_BASE "crystalserver"
$VCPKG_DIR = Join-Path $OT_BASE "vcpkg"

git clone https://github.com/microsoft/vcpkg.git $VCPKG_DIR
& (Join-Path $VCPKG_DIR "bootstrap-vcpkg.bat")
& (Join-Path $VCPKG_DIR "vcpkg.exe") integrate install

[Environment]::SetEnvironmentVariable('VCPKG_ROOT', $VCPKG_DIR, 'User')
$env:VCPKG_ROOT = $VCPKG_DIR
```

Valide:

```powershell
Test-Path (Join-Path $env:VCPKG_ROOT "scripts\buildsystems\vcpkg.cmake")
```

O resultado precisa ser `True`.

## 5. Baixar os repositórios públicos

### Crystal Server

```powershell
git clone https://github.com/zimbadev/crystalserver.git $SERVER_DIR
```

### Cliente base limpo, somente para referência

```powershell
$CLIENT_BASE = Join-Path $OT_BASE "otclient-base-limpo"
git clone https://github.com/opentibiabr/otclient.git $CLIENT_BASE
```

Não use o cliente base limpo para substituir o cliente personalizado.

## 6. Restaurar nosso cliente personalizado

Copie `CrystalClient-Fonte-Personalizado.zip` do backup externo para o computador. Depois execute:

```powershell
$ARQUIVO_BACKUP = Join-Path ([Environment]::GetFolderPath('Desktop')) "CrystalClient-Fonte-Personalizado.zip"

New-Item -ItemType Directory -Path $CLIENT_DIR -Force
Expand-Archive -LiteralPath $ARQUIVO_BACKUP -DestinationPath $CLIENT_DIR -Force

Test-Path (Join-Path $CLIENT_DIR "tools\compilar-e-empacotar.ps1")
Test-Path (Join-Path $CLIENT_DIR "tools\criar-instalador.ps1")
Test-Path (Join-Path $CLIENT_DIR "installer\CrystalClient.iss")
Test-Path (Join-Path $CLIENT_DIR "cmake\icon\otcicon.ico")
```

Os quatro resultados precisam ser `True`.

## 7. Criar uma configuração CMake nova

Não restaure a pasta `build` de outro Windows. Gere uma configuração nova.

Para o Crystal Client no Windows, padronizamos a pasta de configuração Release em:

```text
build\windows-release
```

Configure assim:

```powershell
$TOOLCHAIN = Join-Path $VCPKG_DIR "scripts\buildsystems\vcpkg.cmake"

cmake -S $CLIENT_DIR -B (Join-Path $CLIENT_DIR "build\windows-release") `
  -G "Visual Studio 18 2026" `
  -A x64 `
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" `
  -DVCPKG_TARGET_TRIPLET=x64-windows `
  -DVCPKG_BUILD_TYPE=release `
  -DBUILD_STATIC_LIBRARY=OFF `
  -DSPEED_UP_BUILD_UNITY=ON `
  -DOTCLIENT_BUILD_CLIENT=ON `
  -DOTCLIENT_BUILD_TESTS=OFF
```

A primeira configuração baixa e compila dependências do vcpkg e pode demorar bastante.

> **Importante:** este projeto usa `x64-windows` para a build normal do cliente. Não misture
> `x64-windows-static-release` com `BUILD_STATIC_LIBRARY=OFF`, pois isso pode causar erros
> `LNK2038` de incompatibilidade entre `/MT` e `/MD`.

Quando terminar corretamente, o CMake exibirá algo semelhante a:

```text
-- Configuring done
-- Generating done
-- Build files have been written to: D:/otclient-main/build/windows-release
```

## 8. Compilar o cliente Release

Feche qualquer `otclient.exe` ou `Crystal.exe` aberto antes de compilar:

```powershell
cd $CLIENT_DIR
```

### 8.1 Build normal / incremental

Use esta opção no dia a dia:

```powershell
cmake --build build/windows-release --config Release --parallel
```

Ela reaproveita o que já foi compilado e recompila somente o que mudou.

É a melhor opção para alterações normais em código-fonte, módulos, scripts e recursos.

- `--build build/windows-release`: usa a configuração CMake já criada nessa pasta.
- `--config Release`: gera a versão Release, otimizada para distribuição.
- `--parallel`: permite ao sistema de build usar vários núcleos da CPU para acelerar a compilação.

### 8.2 Build limpa / completa

Quando precisar recompilar tudo do zero dentro da configuração atual, use:

```powershell
cmake --build build/windows-release --config Release --clean-first --parallel
```

A opção `--clean-first` limpa os objetos compilados antes de iniciar a nova build.

Use principalmente quando:

- houve alteração importante em CMake;
- houve alteração em bibliotecas ou dependências;
- mudou alguma configuração de compilação;
- apareceram erros estranhos causados por objetos antigos;
- você quer validar uma Release completamente recompilada.

A build limpa demora mais porque não reaproveita os objetos já compilados.

### 8.3 Diferença rápida

| Comando | Quando usar | Velocidade |
|---|---|---|
| `cmake --build build/windows-release --config Release --parallel` | Builds normais do dia a dia | Mais rápida |
| `cmake --build build/windows-release --config Release --clean-first --parallel` | Mudanças grandes, problemas de cache ou validação completa | Mais lenta |

### 8.4 Saída da build

No Windows Release, o projeto gera o executável final em:

```text
D:\otclient-main\dist\CrystalClient\Crystal.exe
```

e também executa a sincronização do conteúdo necessário para:

```text
D:\otclient-main\files\
```

Confira o executável:

```powershell
Test-Path (Join-Path $CLIENT_DIR "dist\CrystalClient\Crystal.exe")
Get-Item (Join-Path $CLIENT_DIR "dist\CrystalClient\Crystal.exe")
```

## 8.1 Compilar e empacotar tudo com um comando

Depois que o projeto já tiver sido configurado pelo CMake ao menos uma vez,
use este bloco para compilar o cliente Windows, sincronizar a pasta `files` e
criar os pacotes do cliente e do updater:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd D:\otclient-main
.\tools\compilar-e-empacotar.ps1 -Build
```

Esse único comando produz e atualiza:

```text
files\init.lua
files\data\
files\modules\
files\mods\
dist\CrystalClient\Crystal.exe
dist\servidor\api\updater.php
dist\servidor\files\otclient_x64.exe
dist\RELATORIO-COMPILACAO.txt
```

O APK Android usa WSL e permanece no tutorial separado
`TUTORIAL-ATUALIZAR-E-BUILDAR-ANDROID.md`.

## 9. Empacotar o cliente e os arquivos do updater

O script usa o Release que você acabou de compilar:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd $CLIENT_DIR
.\tools\compilar-e-empacotar.ps1
```

Resultados:

```text
dist\CrystalClient\Crystal.exe
dist\servidor\api\updater.php
dist\servidor\files\otclient_x64.exe
dist\RELATORIO-COMPILACAO.txt
```

Sempre que o empacotador encontrar uma pasta `dist` anterior, ele a preserva automaticamente em `backups`.

## 10. Criar o instalador do Windows

```powershell
cd $CLIENT_DIR
.\tools\criar-instalador.ps1 -Version "1.0.0"
```

Para uma atualização futura:

```powershell
.\tools\criar-instalador.ps1 -Version "1.0.1"
```

O instalador será criado em:

```text
dist\instalador\CrystalClient-Setup-1.0.0.exe
```

Confira o hash antes de publicar:

```powershell
$SETUP = Join-Path $CLIENT_DIR "dist\instalador\CrystalClient-Setup-1.0.0.exe"
Get-Item $SETUP
Get-FileHash $SETUP -Algorithm SHA256
```

## 11. Sequência curta para as próximas versões

Depois que o computador já estiver configurado, use a build incremental na rotina normal:

```powershell
$CLIENT_DIR = "D:\otclient-main"

cd $CLIENT_DIR
cmake --build build/windows-release --config Release --parallel
.\tools\compilar-e-empacotar.ps1
.\tools\criar-instalador.ps1 -Version "1.0.1"
```

Se precisar de uma recompilação completa:

```powershell
cd D:\otclient-main
cmake --build build/windows-release --config Release --clean-first --parallel
```

Resumo:

```text
Sem --clean-first = incremental, mais rápido, recompila somente o necessário.
Com --clean-first = limpa primeiro e recompila tudo, mais lento porém mais seguro para mudanças grandes.
```

## 12. Estrutura esperada na VPS para o updater

Envie o conteúdo de `dist\servidor` mantendo `api` e `files` como pastas irmãs:

```text
/var/www/crystal/
├── api/
│   └── updater.php
└── files/
    ├── otclient_x64.exe
    ├── init.lua
    ├── data/
    ├── modules/
    ├── mods/
    └── DLLs
```

Teste a API pelo Windows:

```powershell
$body = @{
  version = 0
  build = "1.0.0"
  os = "windows"
  platform = "WIN32-WGL"
  args = @{}
} | ConvertTo-Json

Invoke-RestMethod `
  -Uri "https://crystalgames.com.br/api/updater.php" `
  -Method Post `
  -ContentType "application/json" `
  -Body $body
```

Uma resposta válida contém `url`, `files` e `binary`.

## 13. Diagnóstico rápido

### Erro LNK1104 ao abrir `otclient.exe`

Feche o cliente antes de compilar:

```powershell
Get-Process otclient,Crystal -ErrorAction SilentlyContinue
```

### PowerShell bloqueou um script

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

### CMake não encontrou o vcpkg

```powershell
$env:VCPKG_ROOT = $VCPKG_DIR
Test-Path (Join-Path $env:VCPKG_ROOT "scripts\buildsystems\vcpkg.cmake")
```

### Cliente abre e fecha imediatamente

Empacote novamente para copiar todas as DLLs:

```powershell
cd $CLIENT_DIR
.\tools\compilar-e-empacotar.ps1
```

### Recursos 15.25 ausentes

Confirme se existe uma versão dentro de `data\things` e `data\sounds`. Se essas pastas estiverem vazias, o instalador automático de recursos precisará baixá-las no primeiro uso.
