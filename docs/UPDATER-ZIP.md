# Updater com ZIP

O PHP do projeto fica em `tools/api/updater.php` e é publicado como `/var/www/crystalgames/api/updater.php`. O cliente usa `modules/updater/updater.lua`. Os binários continuam separados por sistema e arquitetura.

Para testar, feche e abra novamente o cliente instalado. Seu Lua do updater foi atualizado para negociar ZIPs com a API; o executável não foi trocado e não houve compilação.

1. Execute o build normalmente a partir da raiz. Ao concluir, a sincronização gera `files/data.zip`, `files/modules.zip` e `files/mods.zip`, cada um contendo sua pasta correspondente. Isso vale para Release e Debug, em todas as plataformas com sincronização do updater. Também é possível compactar as pastas manualmente para um teste, usando ZIP comum, sem senha.
2. Envie os ZIPs para `/var/www/crystalgames/api/files/`. Mantenha inicialmente as pastas descompactadas nesse diretório: clientes antigos continuam precisando delas até receberem o updater novo.
3. Deixe `init.lua`, `Crystalx86.exe`, `Crystalx64.exe`, executáveis Linux e APK fora desses três ZIPs. Eles seguem o mecanismo atual de seleção por plataforma/arquitetura.
4. Abra o cliente. Havendo conteúdo diferente, o updater baixa um ZIP por grupo, verifica CRC32 e SHA-256, extrai para a pasta de instalação e reinicia uma vez, após concluir todos os grupos.

São aceitos os dois layouts abaixo:

```text
data.zip -> data/images/..., data/things/1525/..., data/sounds/1525/...
data.zip -> images/..., things/1525/..., sounds/1525/...
```

O mesmo vale para `modules` e `mods`. Não misture uma pasta externa adicional, como `meu-cliente/data/...`, nem DLLs/executáveis nesses pacotes. O cliente continua lendo as pastas padrão; os ZIPs servem somente para transporte.

## Qual conteúdo prevalece

A comparação de datas ocorre na VPS, entre cada ZIP e sua pasta correspondente. O ZIP é usado quando sua data de modificação é igual ou posterior à maior data da pasta, dos arquivos e das subpastas. Se a pasta tiver conteúdo mais recente, são oferecidos os arquivos individuais. Sem ZIP, o comportamento continua por arquivo. No cliente, os hashes determinam o que já está atualizado: um ZIP com conteúdo já instalado não é baixado novamente.

Envie o ZIP após atualizar a pasta no servidor. Se seu programa de transferência preservar datas antigas, confira as datas de modificação na VPS; a data considerada é a do arquivo no servidor, não a data interna do ZIP. Regenere o ZIP quando modificar seu conteúdo. Um manifesto GitHub publicado continua sendo a fonte oficial para os caminhos que ele define e não é substituído por ZIP local.

O ZIP escolhido é a fonte do manifesto para aquele grupo. Portanto, novos clientes também aceitam ZIPs sem a pasta equivalente na VPS, mas isso não atende aos clientes antigos; mantenha ambos durante a migração.

## Limites desta etapa

Os ZIPs são recriados após a sincronização dos recursos em cada build, sem precisar instalar um compactador. As pastas descompactadas continuam em `files/` para clientes antigos. Debug atualiza recursos e ZIPs, preservando os binários Release. O envio à VPS continua manual. ZIPs preparados manualmente em `files/` serão substituídos pelo conteúdo atual do projeto no próximo build. Não há desativação do Defender nem alteração das opções `strictManifestSha256` e `allowRawFallbackHashMismatch`.

A extração usa as funções nativas já existentes, inclusive o suporte ZIP sem libarchive no Android. Os downloads são mantidos em memória pelo mecanismo atual; para pacotes muito grandes, teste o consumo de memória principalmente no cliente x86. A extração nativa pode demorar com muitos arquivos; a tela mostra a etapa antes de iniciá-la.

## Validação

PHP: formatos com/sem pasta interna, SHA/CRC, atualização imediata do cache após mudanças nos arquivos, escolha pela data, ZIP sem pasta no servidor, compatibilidade antiga, Windows/Linux x86/x64, separação Android, caminhos inválidos, pacotes nativos e ZIP corrompido. A compatibilidade do manifesto GitHub também foi verificada.

Lua: download de um ZIP por grupo, ausência de downloads duplicados, reinício após as extrações, CRC/SHA incorretos, falha de extração, nenhuma atualização necessária e alternativa por arquivo. A lógica Lua foi executada com os serviços do cliente simulados; a extração gráfica com seus ZIPs reais precisa do seu teste.
