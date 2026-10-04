# Compilar Crystal para navegador no WSL

Execute sempre na raiz do projeto. O SDK utilizado e Emscripten 4.0.23.
Os presets encontram automaticamente `~/emsdk` e `~/vcpkg`; se estiverem em
outros caminhos, defina `EMSDK` e `VCPKG_ROOT` no terminal. O fluxo web limpa `CC`/`CXX`
herdados para que o vcpkg escolha emcc/em++ para o navegador e o compilador
nativo para ferramentas de host; nao exporte GCC manualmente para esse fluxo. Nao ha caminhos de
uma maquina especifica nos presets, nem e necessario ativar o SDK no `.bashrc`.

## Outra maquina: preparar dependencias

No Ubuntu/WSL, instale GCC/G++ 13, CMake >= 3.24, Ninja, Python 3 com venv,
Git, curl, pkg-config, autoconf, autoconf-archive, automake, libtool/libtool-bin,
nasm, bison, flex, zip, unzip e tar. O script informa a lista se faltar ferramenta.

```bash
bash dist/scripts/web-release/preparar-ambiente.sh
```

O script instala/ativa o SDK e prepara vcpkg quando ausente. Nao compila o cliente.
Nao substitui os compiladores dos presets Windows, Linux ou Android.

## Release

```bash
cmake --preset web-release
cmake --build build/web-release -j 10
```

## Debug

```bash
cmake --preset web-debug
cmake --build build/web-debug -j 10
```

Os originais, bibliotecas, caches, Lua 5.1.5 e simbolos ficam em `build/<preset>/`.
A compilacao atualiza automaticamente `dist/web-release/` ou `dist/web-debug/`,
com `index.html`, JavaScript, WebAssembly e o pacote de recursos `.data`.
Nenhum binario desktop nem o payload `files/` e substituido por um build web.
O manifesto de dependencias web fica em `browser/vcpkg.json`; versoes seguem o
baseline da base. Bibliotecas de sistema desktop sao substituidas pelos recursos
WebGL/OpenAL do Emscripten. Lua e baixada de lua.org com SHA256 fixo e compilada
com o mesmo SDK, sem depender do antigo arquivo binario `browser/include/lua51/liblua.a`.

## Abrir o teste local

```bash
python3 dist/scripts/web-release/servir.py
```

Abra `http://localhost:8080/` no navegador. Para Debug:

```bash
python3 dist/scripts/web-release/servir.py --preset web-debug
```

O servidor local envia COOP/COEP, exigidos pelo SharedArrayBuffer/pthreads.
Nao abra `index.html` com `file://`. Para compilar por SSH e abrir em outra
maquina, use um tunel SSH para a porta 8080; a conexao deve permanecer aberta.

## Limites da etapa atual

Preparar o ambiente nao valida o cliente completo. A primeira configuracao e
compilacao devem ser executadas pelo usuario. Abrir o jogo no navegador e uma
etapa distinta: requer WebGL2, servidor com HTTPS e COOP/COEP, e uma conexao
WebSocket adequada ao servidor TCP. Release usa `wss://`, Debug usa `ws://`.
O servidor de teste HTTP nao resolve a ponte WebSocket do jogo.
A configuracao atual incorpora data/modules/mods e reserva 1 GiB de memoria;
reduzir carga inicial e validar updater/recursos em navegador e trabalho posterior.
Nenhuma alteracao ou publicacao na VPS e realizada automaticamente.
