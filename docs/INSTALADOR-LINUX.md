# Linux: configurar, compilar e distribuir

Todos os comandos sao executados pelo usuario, a partir da raiz do projeto no Linux ou WSL. Os presets usam caminhos relativos a raiz; em outra maquina instale as ferramentas e execute os mesmos comandos, sem editar presets.

## Presets

| Preset | Uso |
| --- | --- |
| linux-x86-release | Release nativo de 32 bits |
| linux-x86-debug | Debug nativo de 32 bits |
| linux-x64-release | Release nativo para o sistema onde compila |
| linux-x64-debug | Debug nativo |
| linux-x64-portable-release | Release em Docker, base glibc 2.35 |
| linux-x64-portable-debug | Debug no mesmo ambiente Docker |

Arquiteturas nativas: Linux x86 (32 bits) e x64 (64 bits). O fluxo Docker portatil permanece x64. Os nomes antigos foram substituidos nos comandos; builds e pacotes anteriores permanecem no disco.

## Build nativo

```bash
cd /mnt/d/otclient-main
cmake --preset linux-x64-release
cmake --build build/linux-x64-release -j 10
bash dist/scripts/linux-x64-release/empacotar.sh --version 1.0.0
```

Troque o preset por linux-x64-debug para Debug, inclusive no caminho do script. Fora do WSL, entre na raiz onde clonou o projeto; /mnt/d/otclient-main nao e um caminho exigido pelos scripts.

- build/<preset>/bin/Crystal: original com as informacoes de depuracao disponiveis.
- build/<preset>/: objetos, dependencias, cache, staging e recuperacao.
- dist/<preset>/: executavel sem simbolos de depuracao e somente recursos para abrir o updater.
- dist/scripts/<preset>/empacotar.sh: script publico de empacotamento.
- dist/instalador/<preset>/: .tar.gz, .deb, SHA-256 e relatorio de compatibilidade. RPM e opcional.
- files/Crystalx86 e files/Crystalx64: ultimo executavel Linux Release de cada arquitetura. Windows, Android e seus metadados ficam intactos.

Cada build atualiza a distribuicao minima mesmo se apenas Lua/recursos mudarem. Debug nao substitui o binario Linux Release de files/. Execute builds em sequencia porque os recursos de files/ sao compartilhados. Nada e enviado ao servidor automaticamente.

## Outra maquina

Instale GCC/G++ 13, CMake 3.24+, Ninja, Git, vcpkg e ferramentas de build do sistema. O manifesto vcpkg.json e os overlays pertencem ao projeto e definem as bibliotecas C++. vcpkg e encontrado em .tools/vcpkg, ao lado do projeto, em ~/vcpkg, ou por VCPKG_ROOT. Para empacotar, disponibilize CPack, binutils (readelf/strip), tar, coreutils e dpkg-dev para DEB; RPM requer rpmbuild. ccache e opcional.

Leve os fontes, recursos, manifestos e scripts; nao reutilize o CMakeCache.txt de outra maquina. A configuracao precisa rodar uma vez para detectar as ferramentas da nova maquina, mas os caminhos e opcoes do projeto ja estao nos presets.

## Build portatil em Docker

Para distribuir entre sistemas com glibc 2.35 ou superior, escolha o preset portatil. Exige Docker funcional e CMake 3.25+ no controlador:

```bash
cmake --preset linux-x64-portable-release
cmake --build build/linux-x64-portable-release -j 10
bash dist/scripts/linux-x64-portable-release/empacotar.sh --version 1.0.0
```

O compilador GCC 13 e a base do container ja ficam definidos no Dockerfile. Os artefatos de exportacao ficam em build/<preset>/portable-export/, e o cache Docker e reutilizado em volumes. O script verifica a glibc do ELF gerado; nao foi executado um build Docker nesta organizacao.

Empacotar um binario nativo nao reduz a glibc exigida. O .tar.gz e o relatorio informam o minimo detectado. A API seleciona files/Crystalx86 ou files/Crystalx64 pela arquitetura do cliente: ao oferecer pacotes portateis, publique no updater um binario com a mesma compatibilidade. Um build nativo posterior pode exigir glibc mais nova.

## Pacotes e inicializacao

Por padrao o script gera TAR.GZ e DEB. Para selecionar:

```bash
bash dist/scripts/linux-x64-release/empacotar.sh --version 1.0.0 --formats portable
bash dist/scripts/linux-x64-release/empacotar.sh --version 1.0.0 --formats portable,rpm
```

O empacotador consome dist/<preset>/ e nao configura nem compila o cliente. Configura apenas os metadados isolados do CPack para montar DEB/RPM. Pacotes antigos do mesmo destino sao preservados em backups/ antes da substituicao. O launcher em dist/scripts/linux-x64-release/crystal-client.sh e compartilhado pelos seis scripts.

TAR.GZ: extraia e execute ./crystal-client. DEB: instale com o gerenciador de pacotes e abra pelo menu ou execute crystal-client. O launcher roda sem sudo e cria uma copia gravavel pelo usuario em ${XDG_DATA_HOME:-$HOME/.local/share}/crystal-client/client/. Configuracoes ficam em ${XDG_CONFIG_HOME:-$HOME/.config}/crystal-client/. Perfis anteriores em ~/.Crystal sao preservados. O updater continua usando data/things/<version>/ e data/sounds/<version>/ dentro do runtime OTC.

A primeira execucao exige internet e os arquivos atualizados no servidor. Os defaults strictManifestSha256=true e allowRawFallbackHashMismatch=false foram preservados. Depois de compilar, teste a instalacao, download, reinicio, cancelamento da primeira atualizacao e persistencia das configuracoes. Nesta organizacao, validacao de scripts/pacotes usa fixtures isoladas; a compilacao e o teste grafico do cliente ficam com o usuario.

## Dependencias adicionais para x86 no Ubuntu/WSL x64

O preset usa GCC 13 com -m32, triplet x86-linux e ferramentas host x86-linux. Instale as bibliotecas de desenvolvimento de 32 bits antes de configurar:

```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install gcc-13-multilib g++-13-multilib libc6-dev-i386 libx11-dev:i386 libxext-dev:i386 libxrandr-dev:i386 libxi-dev:i386 libxinerama-dev:i386 libxcursor-dev:i386 libgl1-mesa-dev:i386 libglu1-mesa-dev:i386
cmake --preset linux-x86-release
cmake --build build/linux-x86-release -j 10
bash dist/scripts/linux-x86-release/empacotar.sh --version 1.0.0
```

O triplet x86-linux do vcpkg pertence aos triplets da comunidade. A compilacao completa das dependencias x86 sera validada no primeiro build executado pelo usuario. DEB x86 usa i386; RPM x86 usa i686. Nao misture bibliotecas de 64 bits em um build x86.

Publique manualmente tools/api/updater.php junto com os binarios novos: a API entrega Crystalx86 apenas para arch=x86 e Crystalx64 para arch=x64. Clientes x64 antigos ainda podem usar o nome legado Crystal durante a transicao; clientes x86 nunca recebem esse fallback. Cada build Release atualiza somente seu binario. O executavel dentro de dist/<preset>/ continua chamado Crystal.

O host triplet de Linux x86 tambem e x86-linux: o port LuaJIT exige ferramentas buildvm-32 em host nativo de 32 bits. O WSL x64 executa essas ferramentas com as bibliotecas multilib instaladas. Nao use --allow-unsupported para contornar essa verificacao. Linux x64 continua com host x64-linux.
