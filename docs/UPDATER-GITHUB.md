# Publicar recursos pelo GitHub

O cliente consulta a API HTTPS da VPS. Clientes com updaterProtocol=2 recebem URLs por arquivo apontando para um commit imutavel do repositorio publico JoGome-1979/otclient-crystal. Os executaveis e APK continuam em api/files/ na VPS. Recursos presentes apenas na VPS continuam vindo dela, evitando perder assets durante a migracao.

O .gitignore deve preservar mods/, data/things/ e data/sounds/, inclusive .dat e .spr. Apenas caches, marcadores de instalacao, segredos e produtos de compilacao ficam fora. Verifique o conteudo antes do commit; tornar o repositorio publico tambem publica os recursos commitados.

## Primeira publicacao e proximas atualizacoes

1. Revise e envie ao GitHub os fontes/recursos e o novo modules/updater/updater.lua. O script recusa commits que ainda nao incluem updaterProtocol=2.
2. Execute da raiz, no WSL ou em outra maquina com Python 3 e Git:

```bash
python3 tools/publicar-updater-github.py --commit HEAD
```

O arquivo gerado e build/updater/github-release.json. O script calcula CRC32 dos blobs Git (nao das copias locais, que podem usar CRLF), verifica que init.lua e updater.lua desse commit estao publicos no GitHub e fixa o SHA completo no manifesto. Nao configura nem compila o cliente. Nao publica nem faz commit/push automaticamente.

3. Atualize na VPS tools/api/updater.php como /var/www/crystalgames/api/updater.php.
4. Na primeira migracao, publique tambem o novo modules/updater/updater.lua em /var/www/crystalgames/api/files/modules/updater/updater.lua. Clientes antigos baixam essa versao pela VPS, reiniciam e passam a enviar updaterProtocol=2. Mantenha os recursos da VPS atualizados para compatibilidade com instaladores antigos.
5. Envie o manifesto como arquivo temporario e depois renomeie no servidor:

```bash
scp build/updater/github-release.json asat-vps:/var/www/crystalgames/api/github-release.next.json
ssh asat-vps 'cp -p /var/www/crystalgames/api/github-release.json /root/github-release.previous.json 2>/dev/null; mv /var/www/crystalgames/api/github-release.next.json /var/www/crystalgames/api/github-release.json'
```

A troca do manifesto ativa o commit escolhido. Um push sozinho nao publica uma versao no updater. Para reverter, publique um manifesto anterior; para desativar o GitHub, remova/renomeie github-release.json e todos os clientes voltam a baixar da VPS.

## Verificacao

Clientes antigos sem updaterProtocol recebem a resposta anterior com url da VPS. Clientes novos recebem files + fileUrls + githubRelease; somente os recursos Git usam fileUrls. Native binaries nunca entram no manifesto Git. Checksums de download, reinicio, primeira inicializacao e seguranca de client-assets permanecem ativos: strictManifestSha256=true e allowRawFallbackHashMismatch=false. Os caminhos continuam data/things/<version>/ e data/sounds/<version>/.

Testes isolados cobrem CRC divergente, origem GitHub/VPS, resposta antiga, URL HTTPS, caracteres escapados em nomes, caminhos invalidos e selecao de binarios. O teste grafico com um cliente real deve confirmar primeira instalacao e reinicio apos a publicacao.
