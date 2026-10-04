# Instalação Automática de Assets do Cliente

Este documento descreve o fluxo de instalação automática de assets do cliente introduzido no OTClient.

## Objetivo

Para versões modernas do cliente Tibia (>= 1281), o OTClient deve ser capaz de:

1. Detectar assets ausentes para a versão selecionada.
2. Solicitar ao usuário que baixe os assets necessários.
3. Baixar e instalar os assets automaticamente.
4. Manter os arquivos finais instalados nos mesmos caminhos já utilizados pelo runtime do OTC.

## Caminhos Finais de Instalação (Fonte da Verdade)

Os assets instalados devem terminar em:

- `data/things/<version>/`
- `data/sounds/<version>/`
- extras do runtime (quando fornecidos pelo pacote upstream), como `bin/*`, nos caminhos esperados do runtime do cliente.

Não introduza uma raiz alternativa permanente para assets em runtime.

## Módulo Principal

- Módulo Lua: `modules/client_assets/client_assets.lua`
- Integração no início do jogo: `modules/client_entergame/entergame.lua`
- Carregamento moderno de things/sounds: `modules/game_things/things.lua`

## Estratégia de Download / Instalação

O fluxo suporta:

- instalação por arquivo compactado do ZIP da release/tag como caminho padrão
- instalação guiada por manifesto como caminho de fallback quando o arquivo compactado não puder ser instalado
- instalação por identificador de hash do manifesto em `data/things/<version>/assets.json.sha256`
- lista de arquivos empacotados (incluindo binários grandes distribuídos como `.zip`/`.rar`)
- extração de arquivos `.zip` e `.rar`
- descompressão opcional de `.lzma`

## Integridade e Padrões de Segurança

Os padrões são reforçados:

- `strictManifestSha256 = true`
- `allowRawFallbackHashMismatch = false`
- `allowMissingPackedRawFallback = true`

`allowMissingPackedRawFallback` é um fallback de compatibilidade estreita para releases do repositório que referenciam arquivos oficiais `.lzma`/arquivo compactado não armazenados no repositório de assets. Ele só é usado quando necessário e não deve se tornar o comportamento padrão.

O cache de release é limitado por fonte (`releasesUrl` / chave do repositório), evitando reutilização antiga entre fontes diferentes.

## Observações de Runtime / Plataforma

- Alvos desktop usam `libarchive` para extração de arquivos compactados quando disponível.
- Builds sem `libarchive` ainda extraem arquivos `.zip` por meio do fallback vendorizado minizip. Isso mantém o fluxo de ZIP da source do GitHub funcional em builds desktop limpos.
- A extração de `.rar` requer `libarchive`. Se um `.rar` empacotado for opcional e a build não puder extrair, a instalação deve falhar de forma clara ou ignorar conforme a configuração do pacote.
- O fluxo padrão é “primeiro arquivo compactado” porque o ZIP da source da release é o pacote canônico para este repositório. O caminho do manifesto permanece um fallback de compatibilidade, não o caminho principal de instalação.
- O fallback de login para Emscripten foi alinhado com a semântica nativa de `httpLogin`.

## Comportamento da UX

- A caixa de diálogo de assets ausentes é exibida antes do download.
- A janela de download suporta cancelamento.
- O progresso suporta modo indeterminado quando o servidor remoto não fornece tamanho do conteúdo confiável.
- Os logs do console mostram as fases principais e os caminhos finais de instalação.

## Solução de Problemas

### 1) Os assets parecem ter sido baixados, mas o jogo ainda não consegue carregar

Verifique:

- `data/things/<version>/catalog-content.json`
- `data/things/<version>/assets.json.sha256`
- `data/sounds/<version>/catalog-sound.json` (quando os sons estiverem habilitados)

### 2) Arquivo `.lzma` ausente

Se o console mostrar um 404 para `*.lzma`, o cliente está usando o fallback do manifesto em vez do ZIP da release. Primeiro, verifique por que a instalação por arquivo compactado falhou. O fallback do manifesto pode instalar arquivos brutos em vez do pacote comprimido, mas isso não deve ser o caminho preferido.

### 3) Divergência de SHA-256

Por padrão, divergências falham a instalação. Verifique primeiro os arquivos upstream e os hashes antes de alterar as flags de integridade.

### 4) Progresso lento / “travado”

Se o `Content-Length` não estiver presente, a interface pode operar em modo indeterminado durante o download e a extração. Use os logs do console para confirmar a fase ativa.

## Configuração (init.lua)

`Services.clientAssets` oferece controles de comportamento em runtime (repositório, preferência por arquivo compactado, sons, arquivos empacotados, rigor de hash, etc.). Mantenha os padrões seguros, a menos que exista uma compatibilidade específica justificável.

## Checklist de Manutenção

Ao alterar este sistema, valide:

1. A mensagem de assets ausentes aparece para uma versão moderna.
2. A instalação conclui em `data/things/<version>` e `data/sounds/<version>`.
3. O runtime carrega os assets modernos nesses caminhos.
4. O comportamento de verificação de hash corresponde à configuração.
5. A CI do Windows/Linux continua verde; o Android não tenta resolver linkagem de `libarchive` não suportada.
