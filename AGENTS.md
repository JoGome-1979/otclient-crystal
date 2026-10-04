# AGENTS.md

## AGENTS.md Loading Budget

- Keep this root file limited to repository-wide invariants and precise routing gates; place detailed workflows in versioned documentation or skills.
- Codex applies a combined instruction budget (32 KiB by default) across global, root, and nested guidance. Keep mandatory gates first and preserve headroom for narrower scopes.
- Do not raise `project_doc_max_bytes` as the first response to oversized guidance; remove duplication and route conditional detail first.

## Client Assets Gate (Mandatory)

Any change touching client-assets auto-installation must preserve the runtime contract below:

1. **Final install paths must remain OTC-standard**
   - `data/things/<version>/`
   - `data/sounds/<version>/`
   - runtime extras in expected runtime locations (for example `bin/*` when distributed upstream)

2. **No alternate permanent source of truth**
   - Do not move runtime loading to `client-assets/` (or any new root) as the primary runtime path.
   - Temporary/cache directories are allowed only as transient staging, never as final runtime source.

3. **Security defaults stay strict unless explicitly justified**
   - `strictManifestSha256 = true`
   - `allowRawFallbackHashMismatch = false`

4. **Cross-platform build safety**
   - Android must not require unsupported `libarchive` linkage.
   - Desktop archive extraction behavior must remain functional.

5. **Verification required in PR description**
   - Explicitly state tested install paths and expected runtime load behavior.

Reference: `docs/client-assets-auto-install.md`

## Organizacao Windows confirmada (2026-10-03)

- O usuario autorizou organizar a distribuicao Windows. Configuracoes e compilacoes do projeto sao sempre executadas pelo usuario, a partir da raiz; nao execute esses comandos em seu lugar.
- Presets principais: windows-x86-release, windows-x64-release, windows-x86-debug, windows-x64-debug. Comandos: cmake --preset <preset>; cmake --build build/<preset> -j <jobs>.
- Intermediarios e simbolos em build/<preset>/; distribuicao minima em dist/<preset>/; payload completo do updater em files/.
- Scripts publicos em dist/scripts/<preset>/ e pacotes em dist/instalador/<preset>/.
- Instalador unico: dist/scripts/windows-x86_64-release/, saida dist/instalador/windows-x86_64-release/. Consome dist/windows-x86-release/ e dist/windows-x64-release/ e escolhe automaticamente a arquitetura do Windows, sem misturar os runtimes.
- Windows ARM64 ainda nao foi definido. Nao publicar arquivos no servidor automaticamente. Consulte DISTRIBUICAO.md e docs/INSTALADOR.md.

- O usuario vai iniciar o novo repositorio: o .git anterior foi removido a pedido. Nao execute git init, git add ou commits sem nova instrucao. Pacotes existentes ficam no disco, ignorados pelo .gitignore; guarde no Git apenas fontes, recursos necessarios, configuracoes e scripts.

- Binarios Windows do updater devem ficar diretamente em files/Crystalx86.exe e files/Crystalx64.exe. Nao gerar files/binaries/ nem duplicar Crystal.exe. Os nomes Clientex86.exe/Clientex64.exe dos pacotes instalaveis permanecem separados desta publicacao.

- Linux usa linux-x64-release/debug e linux-x64-portable-release/debug. Mesmos caminhos por preset: build/, dist/, dist/scripts/, dist/instalador/. O usuario executa configure/build. Scripts .sh de empacotamento devem acompanhar o Git. files/Crystalx86 e files/Crystalx64 so sao atualizados pelo build Linux Release correspondente; binarios Windows/Android permanecem intactos.

Linux nativo inclui linux-x86-release/debug e linux-x64-release/debug. x86 usa GCC 13 multilib (-m32) e vcpkg x86-linux, host x86-linux. Docker portatil segue x64. Payloads Linux em files/Crystalx86 e files/Crystalx64; API seleciona pela arquitetura e nunca oferece fallback x64 a clientes x86. Executavel instalado continua Crystal.

Web: presets web-release/web-debug no WSL/Linux, SDK Emscripten 4.0.23. Configure/build do cliente sao executados pelo usuario. Leia docs/CLIENTE-WEB.md; fontes/cache em build/<preset>, artefatos web em dist/<preset>, ferramentas em dist/scripts/web-release. Build web nao publica nem altera files/ ou a VPS. Validacoes de fixtures isoladas do SDK nao sao builds do cliente.
