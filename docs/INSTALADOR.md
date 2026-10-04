# Instalador Windows x86/x64

Siga `DISTRIBUICAO.md` para os quatro presets, caminhos e comandos. O script principal e `dist/scripts/windows-x86_64-release/criar-instalador.ps1`; sua definicao Inno e CrystalClient.iss na mesma pasta.

O script valida os executaveis PE x86/x64 e os recursos de inicializacao de `dist/windows-x86-release/` e `dist/windows-x64-release/`, sem executar configuracao ou compilacao. Cada pasta entra no instalador com uma verificacao exclusiva da arquitetura do Windows. Nao ha selecao manual. Os atalhos e a abertura ao final apontam para Clientex86.exe ou Clientex64.exe conforme o sistema. Em atualizacoes, o executavel da outra arquitetura e removido da pasta instalada. A identidade do aplicativo e a pasta gravavel `{localappdata}/Programs/Crystal Client` foram preservadas.

A distribuicao minima contem somente o updater e seus recursos. O init.lua do pacote inicial encerra o cliente se o primeiro download for cancelado ou incompleto. O payload completo permanece em files/; Debug nao substitui os binarios Release.

A API recebe `g_app.getBuildArch()` no campo arch e seleciona o executavel em files/Crystalx86.exe ou files/Crystalx64.exe. Antes de distribuir x86, publique manualmente tools/api/updater.php e files/. Clientes antigos sem arch continuam com a compatibilidade x64. Os caminhos finais data/things/<version>/ e data/sounds/<version>/ e os defaults strictManifestSha256=true e allowRawFallbackHashMismatch=false permanecem iguais.

## Verificacao apos suas compilacoes

1. Gere o instalador depois dos dois builds Release.
2. Instale em Windows 32 bits: somente Clientex86.exe deve estar presente e os atalhos devem abri-lo.
3. Instale em Windows x64: somente Clientex64.exe deve estar presente, inclusive em instalacao silenciosa.
4. Em uma pasta nova, abra com internet, conclua o updater e confirme dados, modulos, data/things/1525/ e data/sounds/1525/ nos caminhos OTC.
5. Cancele o primeiro download e reabra para repetir; depois da atualizacao completa, teste abrir sem internet.

Nesta organizacao os testes de scripts usam fixtures isoladas; a compilacao real e a execucao do novo cliente ficam a cargo do usuario. Os pacotes antigos nao comprovam que os quatro novos presets ja foram compilados.
