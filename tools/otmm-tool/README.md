# OT Mapas para Windows

Aplicativo portátil em português. Execute `bin/OTMapas.exe` no Windows 10/11 com .NET Framework 4.5 ou superior.

## Fluxo do mapa do servidor e do editor

O `world.otbm` recebido da VPS contém um fluxo GZIP (`1F 8B`), apesar da extensão `.otbm`. O editor trabalha com os mesmos dados OTBM descompactados; depois da edição, o servidor precisa receber GZIP novamente, ainda com extensão `.otbm`.

Na aba **Descompactar**, clique em **Abrir arquivo**, escolha o mapa `.otbm` da VPS, clique em **Descompactar** e **Salvar como**. O resultado é um `.otbm` para o editor. Depois de salvar, clique em **Abrir no editor…** para passar esse mapa ao Canary Map Editor.

Depois de editar e salvar no editor, feche o mapa. Na aba **Compactar**, abra o `.otbm` editado, clique em **Compactar** e **Salvar como**. O resultado é GZIP `.otbm`, pronto para o servidor.

Se o Canary Map Editor ainda não tiver assets configurados, o aplicativo localiza o cliente Tibia instalado em `%LOCALAPPDATA%\Tibia\packages\Tibia` e configura o caminho que contém `package.json` e `assets\catalog-content.json`. Se esse cliente não estiver instalado, o aplicativo pede para selecionar a pasta correspondente. Isso corrige o erro “Assets directory not found” mostrado pelo editor. Se o editor já estiver aberto com o caminho antigo, feche-o e clique novamente em **Abrir no editor…** para que ele carregue os assets ao iniciar.

O arquivo de origem nunca é substituído. Se o destino escolhido já existir, a versão anterior é guardada em `backups\<data-hora>\<compactado|descompactado>\` dentro da pasta de destino, antes de gravar o resultado. Spawns, casas e outros arquivos externos do mapa não são compactados junto; preserve os arquivos auxiliares que seu servidor usa.

## Sincronizar com o CrystalServer por SSH

Na aba **Servidor SSH**, informe o host ou alias, usuário/porta (opcionais quando definidos em `~/.ssh/config`) e o caminho remoto. O padrão é `/home/crystal/crystalserver/data-global/world/world.otbm`. Use uma chave SSH disponível no `ssh-agent` ou no seu perfil; o app não guarda senha nem chave privada e exige que a chave do servidor já esteja validada em `known_hosts`. Se necessário, conecte uma vez pelo PowerShell com `ssh usuario@host` e confira a impressão digital antes de aceitar.

Clique em **Baixar mapa da VPS**. O arquivo vai para `%LOCALAPPDATA%\OTMapas\CrystalServer\downloads`, é validado como GZIP/OTBM e aparece selecionado na aba **Descompactar**. Faça a edição e a compactação pelas duas abas existentes. Em **Servidor SSH**, clique em **Publicar mapa compactado**, escolha o resultado GZIP `.otbm` e confirme que o servidor está parado ou em manutenção.

Antes de substituir o arquivo remoto, o app compara o mapa atual com o snapshot baixado, valida GZIP e SHA-256, cria um backup ao lado do mapa e troca o arquivo por rename atômico. O usuário SSH precisa conseguir gravar na pasta e o arquivo temporário deve ficar com o mesmo proprietário/grupo do mapa existente. A publicação não recarrega o mapa que está na memória do servidor; pare o CrystalServer antes de publicar e inicie-o depois. Não use `/reload` para isso.

## Testes e compilação

Compile com `powershell -NoProfile -ExecutionPolicy Bypass -File tools/otmm-tool/build.ps1`. Rode `test.ps1` na pasta do aplicativo para verificar GZIP/OTBM, integridade, entradas inválidas, comandos de publicação SSH e as três abas. `test-real-map.js` aceita o mapa real como primeiro argumento e um destino novo como segundo; compara a ida e volta com zlib independente, confere a estrutura OTBM e verifica que a origem permanece intacta.
