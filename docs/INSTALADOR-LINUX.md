# Pacotes e atualizacao do Crystal no Linux

## Gerar os pacotes

Na raiz do projeto, depois de compilar o executavel com as correcoes:

```bash
cmake --build --preset linux-release -j 4
./tools/criar-pacotes-linux.sh --version 1.0.0
```

O script gera um portatil `.tar.gz` e um `.deb` em `dist/linux-packages/`, com SHA-256 e um relatorio de compatibilidade. O pacote inclui somente o executavel e os mesmos modulos iniciais do instalador Windows, incluindo `modules/updater` e as dependencias que abrem sua interface. Os demais modulos, sprites e sons sao baixados na primeira abertura. O binario original nao e removido nem alterado pelo empacotamento; apenas a copia distribuida tem os simbolos de depuracao retirados.

Para RPM, instale a ferramenta `rpmbuild` da sua distribuicao e execute:

```bash
./tools/criar-pacotes-linux.sh --version 1.0.0 --formats portable,rpm
```

E possivel selecionar so `portable`, `deb` ou `rpm`. RPM nao foi gerado neste ambiente porque `rpmbuild` nao esta disponivel.

## Abrir ou instalar

Portatil: extraia o `.tar.gz` e execute `./crystal-client` dentro da pasta extraida. Mantenha essa pasta para que o lancador possa encontrar seu pacote inicial. O updater utiliza uma copia por usuario, inclusive quando a pasta extraida esta em um local compartilhado.

DEB: use o gerenciador de pacotes, por exemplo `sudo apt install ./crystal-client_1.0.0_amd64.deb`. Depois abra pelo menu ou execute `crystal-client` sem sudo. O pacote instala um lancador, icone, atalho e arquivos iniciais em `/usr/lib/crystal-client/`; o updater nunca precisa modificar essa pasta do sistema.

## Arquivos por usuario

O lancador cria:

- Cliente atualizavel: `${XDG_DATA_HOME:-$HOME/.local/share}/crystal-client/client/`.
- Configuracoes: `${XDG_CONFIG_HOME:-$HOME/.config}/crystal-client/`.

Os caminhos finais de recursos continuam sendo `data/things/<version>/`, `data/sounds/<version>/` e os demais caminhos OTC, relativos a pasta do cliente. Nao foi criado outro diretorio de assets como fonte permanente. O lancador passa `--user-dir` para separar configuracoes de recursos atualizados e respeita um `--user-dir` explicitamente fornecido pelo usuario. Na primeira migracao, copia os perfis antigos de `~/.Crystal/`, sem apagar os originais nem sobrescrever configuracoes novas.

Nao abra o cliente com sudo. Se a instalacao anterior criou arquivos pertencentes a root em `~/.Crystal`, verifique o proprietario dessa pasta; a migracao precisa conseguir ler seus arquivos. Pastas de configuracao ou runtime previamente pertencentes a root tambem precisam ter a propriedade corrigida pelo administrador para esse usuario. Nao e necessario dar permissao 777 nem tornar `/usr/lib` gravavel.

O lancador instala o pacote inicial apenas quando o identificador da versao instalada muda ou faltam os arquivos principais. Nas aberturas seguintes, preserva o executavel e os arquivos que o updater baixou.

## Compatibilidade com distribuicoes

Um DEB ou RPM nao muda as bibliotecas exigidas pelo executavel. O binario examinado nesta sessao exige glibc 2.43; os pacotes gerados com ele declaram essa exigencia. O nome do portatil tambem informa a versao minima de glibc. Esses pacotes nao devem ser apresentados como compativeis com distribuicoes que ainda usam glibc mais antiga.

Para uma base mais ampla, o projeto ja tem um build em Ubuntu 22.04 com runtime C++ estatico e limite de glibc 2.35. Ele exige Docker disponivel:

```bash
cmake --preset linux-portable-release
cmake --build --preset linux-portable-release
./tools/criar-pacotes-linux.sh --version 1.0.0 \
  --binary "$PWD/dist/linux-portable-Release/client/Crystal"
```

Use esse binario tambem no updater do servidor quando oferecer a mesma versao para diferentes distribuicoes: a API atual entrega um unico `files/Crystal` para os backends Linux. Publicar depois um executavel com glibc mais nova pode quebrar clientes de uma distribuicao antiga mesmo que o instalador inicial fosse compativel. Os pacotes continuam destinados a Linux x86-64 com X11/OpenGL; o build nao e para ARM64 ou musl.

## Correcoes de gravacao

O ResourceManager agora verifica falhas ao selecionar o diretorio de atualizacao, confirma a escrita/fechamento dos arquivos e devolve falha ao updater. O updater interrompe a etapa antes de reiniciar quando nao consegue instalar arquivos ou substituir o executavel. Ele aceita tambem o retorno antigo sem valor, para manter compatibilidade com clientes antigos durante a atualizacao.

No Linux, o executavel novo recebe a permissao de execucao e substitui o nome estavel por rename atomico. O reinicio passa a usar a versao baixada, em vez de continuar no executavel antigo. O diretorio de configuracoes e restaurado depois da gravacao dos arquivos.

## Verificacao

Foram executados testes nativos das rotinas de atualizacao com PhysFS real: gravacao em runtime, preservacao do diretorio de configuracoes, falha em pasta inexistente/sem permissao, preservacao do executavel diante de download ausente e substituicao do binario Linux com permissao de execucao.

O lancador foi testado com um cliente simulado: configuracoes persistem em pasta separada, o executavel atualizado nao e sobrescrito numa nova abertura, `--user-dir` personalizado e respeitado e o pacote inicial permanece intacto.

Teste final no desktop: instale como administrador, abra como usuario normal, baixe a atualizacao, confirme o reinicio, mude uma opcao e reabra o cliente para verificar sua persistencia. Confira o carregamento dos recursos em `data/things/1525/` e `data/sounds/1525/`. Publique `files/` atualizado no servidor antes desse teste.

As opcoes `strictManifestSha256 = true` e `allowRawFallbackHashMismatch = false` do instalador de assets foram preservadas. A interface grafica nao foi testada neste ambiente.

Nesta sessao, a compilacao dos objetos e a ligacao do executavel Linux foram concluidas. A copia completa de recursos e a sincronizacao de `files/` foram interrompidas para nao disputar esse diretorio com um build Android ativo. O binario novo foi preservado em `build/updater-releases/Crystal`; uma sincronizacao posterior reutiliza essa versao. Antes de publicar no servidor, conclua as compilacoes ativas e sincronize `files/` para incluir tambem o updater Lua atualizado. Os pacotes usam diretamente o executavel novo e os modulos da fonte atual, sem depender da copia completa em `dist/dist-linux/`.
