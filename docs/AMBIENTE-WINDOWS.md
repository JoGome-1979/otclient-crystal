# Preparar outra maquina Windows

As escolhas de compilacao ficam em CMakePresets.json, cmake/triplets/, vcpkg.json e vcpkg-configuration.json. O manifesto ja fixa uma baseline de dependencias. Leve esses arquivos e os fontes, incluindo overlay-ports/ e os scripts em dist/scripts/.

## Dependencias da maquina

Instale Git, CMake 3.24 ou superior, Ninja e Visual Studio 2022 ou Build Tools 2022 com desenvolvimento Desktop C++, MSVC v143 x86/x64 e Windows SDK. Para gerar o instalador, instale Inno Setup 6.3+ ou 7. sccache e opcional: a falta dele nao impede o build. Nao e necessario instalar cada biblioteca C++ manualmente; vcpkg utiliza o manifesto do projeto.

Instale vcpkg, por exemplo no diretorio padrao do usuario:

```bat
git clone https://github.com/microsoft/vcpkg "%USERPROFILE%\vcpkg"
"%USERPROFILE%\vcpkg\bootstrap-vcpkg.bat" -disableMetrics
```

O projeto encontra automaticamente vcpkg em `.tools/vcpkg/` dentro da raiz, em `../vcpkg/` ao lado do projeto ou em `%USERPROFILE%/vcpkg/`. Tambem preserva a localizacao legada D:/vcpkg. Para outra localizacao, defina a variavel de ambiente `VCPKG_ROOT` uma vez na maquina, apontando para a instalacao. Nenhum caminho deve ser alterado nos presets.

## Compilar

Abra o terminal Native Tools do Visual Studio correspondente a arquitetura e entre na raiz do projeto:

```bat
cmake --preset windows-x64-release
cmake --build build/windows-x64-release -j 10
```

Para x86, use o terminal x86 e windows-x86-release. Debug usa windows-x64-debug ou windows-x86-debug. O projeto verifica se o compilador corresponde ao preset. A primeira configuracao instala/compila dependencias ausentes e pode demorar; depois o cache local e reutilizado.

A configuracao CMake sempre precisa ser executada uma vez em uma maquina nova. O que deixa de ser necessario e editar caminhos e opcoes do projeto. Nao reutilize a pasta build/ da maquina anterior: CMake guarda caminhos absolutos, compilador e SDK no cache. Os fontes e scripts podem estar em outro disco ou pasta, inclusive com espacos.

As pastas build/, files/, dist/<preset>/ e dist/instalador/ sao geradas. Os scripts em dist/scripts/ sao fontes e devem acompanhar o projeto. CMakeUserPresets.json, se existir, e local da maquina. O cache compartilhado e opcional e depende das variaveis de ambiente da maquina; nao e requisito para os presets principais.
