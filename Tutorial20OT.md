# Tutorial Cliente OT

## Compilando o OTClient no Windows do zero

Este tutorial utiliza a seguinte estrutura:

``` text
D:\
├── otclient-main\
│   ├── CMakeLists.txt
│   ├── CMakePresets.json
│   ├── vcpkg.json
│   ├── src\
│   ├── modules\
│   └── ...
│
└── vcpkg\
    ├── vcpkg.exe
    └── ...
```

-   **Projeto:** `D:\otclient-main`
-   **vcpkg:** `D:\vcpkg`

O OTClient contém o código que queremos transformar em programa. O vcpkg
cuida das bibliotecas externas necessárias para compilá-lo.

## 1. Antes de começar

Precisamos ter instalados no Windows:

-   Visual Studio com ferramentas de desenvolvimento C++;
-   CMake;
-   Git;
-   vcpkg;
-   código-fonte do OTClient.

Abra o **PowerShell**.

> Não copie o texto `PS C:\Windows\system32>` que aparece antes dos
> comandos. Ele é apenas o prompt do PowerShell.

## 2. Entrar na pasta do OTClient

``` powershell
cd D:\otclient-main
```

Confira:

``` powershell
Get-Location
```

Resultado esperado:

``` text
Path
----
D:\otclient-main
```

## 3. Conferir as ferramentas

CMake:

``` powershell
cmake --version
```

Git:

``` powershell
git --version
```

vcpkg:

``` powershell
D:\vcpkg\vcpkg.exe version
```

Opcionalmente, verifique o compilador:

``` powershell
where.exe cl
```

Dependendo de como o terminal foi aberto, `cl.exe` pode não estar
diretamente no PATH. Isso não significa necessariamente que o CMake não
conseguirá localizar o Visual Studio.

## 4. Verificar os presets

``` powershell
cmake --list-presets
```

Procure pelo preset:

``` text
windows-release
```

Um preset é uma configuração pronta que informa ao CMake como o projeto
deve ser preparado, evitando a necessidade de informar dezenas de opções
manualmente.

## 5. Remover uma compilação anterior

Para realizar uma compilação completamente limpa:

``` powershell
Remove-Item -Recurse -Force D:\otclient-main\build\windows-release -ErrorAction SilentlyContinue
```

Confira:

``` powershell
Test-Path D:\otclient-main\build\windows-release
```

O resultado esperado é:

``` text
False
```

Isso remove somente a compilação anterior. O código-fonte em
`D:\otclient-main` permanece intacto.

### Por que remover o Release?

O CMake armazena informações como:

-   caminho do compilador;
-   caminho do vcpkg;
-   bibliotecas encontradas;
-   arquitetura;
-   opções de compilação;
-   versões;
-   caminhos absolutos.

Essas informações ficam em arquivos como `CMakeCache.txt` e na pasta
`CMakeFiles`. Uma configuração antiga pode causar conflitos depois de
alterações importantes no ambiente.

## 6. Configurar o projeto

``` powershell
cd D:\otclient-main
cmake --preset windows-release
```

Não feche o PowerShell enquanto o processo estiver trabalhando.

O CMake lê arquivos como:

``` text
CMakeLists.txt
CMakePresets.json
vcpkg.json
```

Fluxo simplificado:

``` text
D:\otclient-main
       │
       ▼
     CMake
       │
       ├── lê o projeto
       ├── encontra o Visual Studio
       ├── determina a arquitetura
       ├── encontra/configura o vcpkg
       ├── descobre dependências
       └── prepara a compilação
```

O CMake não é o compilador C++. Ele organiza o processo de construção.

## 7. O papel do vcpkg

Durante a configuração, o projeto pode solicitar diversas bibliotecas
externas. O vcpkg gerencia essas dependências.

``` text
OTClient
   │
   └── precisa de uma biblioteca
              │
              ▼
            vcpkg
              │
       baixa e prepara
              │
       compila e instala
              │
              ▼
          biblioteca
```

Por isso podem aparecer mensagens como:

``` text
Installing...
Building...
Downloading...
Extracting...
```

Uma das dependências deste projeto é o ANGLE:

``` text
angle:x64-windows
```

Quando aparecer:

``` text
Building angle:x64-windows
```

o computador está compilando essa dependência. Essa etapa pode levar
vários minutos.

## 8. Pastas criadas durante a configuração

O CMake recriará:

``` text
D:\otclient-main\build\windows-release
```

A estrutura pode conter:

``` text
windows-release\
│
├── CMakeFiles\
├── vcpkg-buildtrees\
├── vcpkg-packages\
├── vcpkg_installed\
├── CMakeCache.txt
└── vcpkg-manifest-install.log
```

### `CMakeFiles`

Local:

``` text
D:\otclient-main\build\windows-release\CMakeFiles
```

Contém informações internas, regras e arquivos temporários usados pelo
CMake. Não é uma pasta destinada à distribuição para jogadores.

### `vcpkg-buildtrees`

Local:

``` text
D:\otclient-main\build\windows-release\vcpkg-buildtrees
```

Contém arquivos temporários e logs produzidos durante a compilação das
dependências.

Exemplo:

``` text
vcpkg-buildtrees\
└── angle\
```

Podem existir logs como:

``` text
install-x64-windows-rel-out.log
install-x64-windows-rel-out-1.log
error-logs-x64-windows.txt
stdout-x64-windows.log
```

Essa é uma das principais pastas para diagnosticar erros de
dependências.

### `vcpkg-packages`

Local:

``` text
D:\otclient-main\build\windows-release\vcpkg-packages
```

É uma área intermediária utilizada pelo vcpkg durante a preparação dos
pacotes. Não é destinada ao usuário final.

### `vcpkg_installed`

Local:

``` text
D:\otclient-main\build\windows-release\vcpkg_installed
```

Aqui ficam dependências instaladas para o projeto.

Uma estrutura típica:

``` text
vcpkg_installed\
└── x64-windows\
    ├── bin\
    ├── include\
    ├── lib\
    └── share\
```

-   `include`: arquivos `.h` e `.hpp` utilizados pelo código C/C++;
-   `lib`: bibliotecas utilizadas pelo linker;
-   `bin`: pode conter DLLs e executáveis das dependências;
-   `share`: configurações e informações dos pacotes.

## 9. Compilar o OTClient

Quando a configuração terminar sem erros:

``` powershell
cmake --build --preset windows-release
```

Agora acontece a compilação propriamente dita.

O compilador transforma arquivos C++:

``` text
.cpp
```

em arquivos objeto:

``` text
.obj
```

Exemplo:

``` text
game.cpp
    ↓
compilador
    ↓
game.obj
```

Isso acontece com os diversos arquivos que formam o projeto.

## 10. O linker

Depois da compilação, o linker reúne os arquivos objeto e as
bibliotecas:

``` text
game.obj
map.obj
protocol.obj
graphics.obj
...
       +
bibliotecas
       │
       ▼
     LINKER
       │
       ▼
 executável final
```

É nessa etapa que os componentes compilados são unidos para formar o
programa.

## 11. Fluxo completo para iniciantes

Pense no processo como uma fábrica:

``` text
CÓDIGO-FONTE
     │
     ▼
   CMAKE
organiza a construção
     │
     ▼
   VCPKG
fornece as dependências
     │
     ▼
COMPILADOR C++
transforma .cpp em .obj
     │
     ▼
   LINKER
junta os componentes
     │
     ▼
 EXECUTÁVEL
```

De forma extremamente resumida:

``` text
.cpp
 ↓
.obj
 ↓
.exe
```

## 12. Encontrar os executáveis criados

Após o build terminar sem erros:

``` powershell
Get-ChildItem D:\otclient-main\build\windows-release -Recurse -Filter *.exe |
Select-Object FullName
```

## 13. Encontrar as DLLs

``` powershell
Get-ChildItem D:\otclient-main\build\windows-release -Recurse -Filter *.dll |
Select-Object FullName
```

Para procurar EXEs e DLLs ao mesmo tempo:

``` powershell
Get-ChildItem D:\otclient-main\build\windows-release -Recurse -File |
Where-Object { $_.Extension -in ".exe",".dll" } |
Select-Object FullName
```

## 14. Build e distribuição são coisas diferentes

A pasta:

``` text
D:\otclient-main\build
```

é o ambiente de construção. Ela pode conter:

``` text
cache
logs
.obj
bibliotecas
headers
arquivos do CMake
dependências
arquivos temporários
executáveis
```

Grande parte desses arquivos só interessa ao desenvolvedor.

Uma pasta de distribuição, por outro lado, deve conter somente aquilo
necessário para executar o cliente.

Podemos reservar:

``` text
D:\otclient-main\dist
```

Uma estrutura conceitual seria:

``` text
dist\
│
├── OTClient.exe
├── DLLs necessárias
├── modules\
├── data\
├── assets\
├── init.lua
└── demais arquivos necessários em runtime
```

A estrutura exata deve ser definida de acordo com os arquivos realmente
exigidos pelo OTClient.

## 15. Criar a pasta de distribuição

``` powershell
New-Item -ItemType Directory -Force D:\otclient-main\dist
```

Não copie indiscriminadamente toda a pasta `build` para `dist`. Primeiro
identifique quais arquivos o cliente realmente necessita para funcionar.

## 16. Estrutura geral do projeto

``` text
D:\otclient-main
│
├── src\
│   └── código C++ do programa
│
├── modules\
│   └── módulos do OTClient
│
├── data\
│   └── dados utilizados pelo cliente
│
├── CMakeLists.txt
│   └── instruções de construção
│
├── vcpkg.json
│   └── dependências
│
├── build\
│   └── windows-release\
│       ├── CMakeFiles\
│       ├── vcpkg-buildtrees\
│       ├── vcpkg-packages\
│       ├── vcpkg_installed\
│       └── arquivos e binários da compilação
│
└── dist\
    └── versão preparada para distribuição
```

## 17. Comandos resumidos

Depois de entender o processo, uma compilação limpa pode ser executada
seguindo esta sequência.

### Entrar no projeto

``` powershell
cd D:\otclient-main
```

### Remover o Release anterior

``` powershell
Remove-Item -Recurse -Force D:\otclient-main\build\windows-release -ErrorAction SilentlyContinue
```

### Confirmar a remoção

``` powershell
Test-Path D:\otclient-main\build\windows-release
```

### Conferir ferramentas

``` powershell
cmake --version
git --version
D:\vcpkg\vcpkg.exe version
```

### Ver presets

``` powershell
cmake --list-presets
```

### Configurar do zero

``` powershell
cmake --preset windows-release
```

### Compilar

``` powershell
cmake --build --preset windows-release
```

### Encontrar executáveis

``` powershell
Get-ChildItem D:\otclient-main\build\windows-release -Recurse -Filter *.exe |
Select-Object FullName
```

### Encontrar DLLs

``` powershell
Get-ChildItem D:\otclient-main\build\windows-release -Recurse -Filter *.dll |
Select-Object FullName
```

### Criar pasta de distribuição

``` powershell
New-Item -ItemType Directory -Force D:\otclient-main\dist
```

## 18. Resumo

No final, temos três áreas conceitualmente separadas:

``` text
D:\otclient-main
        │
        ├── CÓDIGO-FONTE
        │
        ├── build\
        │      └── ambiente de compilação
        │
        └── dist\
               └── cliente preparado para distribuição
```

O `D:\vcpkg` permanece separado do projeto porque é uma ferramenta de
gerenciamento de dependências e pode ser reutilizado em outros projetos.
