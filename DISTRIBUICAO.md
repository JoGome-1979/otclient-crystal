# Distribuicao organizada por preset

Execute todos os comandos da raiz do projeto. A configuracao e a compilacao sao feitas pelo usuario. Os presets, triplets, manifesto de dependencias e scripts pertencem ao projeto; nao precisam ser editados ao trocar de maquina.

## Windows

| Preset | Terminal Visual Studio | Distribuicao minima |
| --- | --- | --- |
| windows-x86-release | x86 Native Tools | dist/windows-x86-release/ |
| windows-x64-release | x64 Native Tools | dist/windows-x64-release/ |
| windows-x86-debug | x86 Native Tools | dist/windows-x86-debug/ |
| windows-x64-debug | x64 Native Tools | dist/windows-x64-debug/ |

Exemplo, sempre da raiz:

```bat
cmake --preset windows-x64-release
cmake --build build/windows-x64-release -j 10
```

Troque somente o nome do preset para as demais variantes. Nao e necessario compilar todas: escolha a que precisa. Para gerar o instalador unico, compile as duas variantes Release.

- `build/<preset>/`: cache, dependencias, objetos, executavel original em `bin/`, simbolos em `symbols/`, staging e arquivos auxiliares.
- `dist/<preset>/`: copia minima necessaria para abrir o updater, atualizada ao terminar cada build, inclusive quando so os recursos mudam.
- `dist/scripts/<preset>/`: scripts de empacotamento. Cada um dos quatro presets tem `empacotar.ps1` para gerar ZIP.
- `dist/instalador/<preset>/`: pacotes ZIP e instaladores gerados.
- `files/`: payload completo compartilhado do updater, com data, modules, mods, init.lua, binarios Release por arquitetura e Android quando disponivel. Mantem os recursos comuns do bootstrap para permitir recuperacao e atualizacao de clientes antigos; o updater baixa somente arquivos ausentes ou diferentes.

Os arquivos `.pdb`, `.ilk`, `.exp`, `.lib`, objetos e logs de compilacao ficam fora do pacote minimo. Debug inclui as DLLs app-local necessarias e destina-se ao desenvolvimento, com o runtime Debug do Visual Studio instalado; nao substitui os executaveis Release publicados em `files/`. Release permanece estatica.

## Empacotar no PowerShell

Instalador unico, apos compilar x86 e x64 Release:

```powershell
.\dist\scripts\windows-x86_64-release\criar-instalador.ps1 -Version 1.0.0
```

Saida: `dist/instalador/windows-x86_64-release/CrystalClient-Setup-1.0.0.exe`. O instalador escolhe automaticamente pela arquitetura do Windows: x86 em 32 bits, x64 em 64 bits. Cada arquitetura recebe somente sua propria distribuicao. ARM64 ainda nao faz parte deste pacote. Necessita Inno Setup 6.3+ ou 7.

ZIP de um preset, por exemplo:

```powershell
.\dist\scripts\windows-x64-release\empacotar.ps1 -Version 1.0.0
```

Saida em `dist/instalador/windows-x64-release/`. Scripts de empacotamento nao configuram nem compilam o cliente. Instaladores e ZIPs de mesmo nome sao preservados em `backups/` antes da substituicao. Pastas de build e pacotes antigos foram mantidos; os nomes antigos de presets continuam como aliases ocultos para compatibilidade. Use os quatro nomes novos nas proximas compilacoes.

Veja `docs/AMBIENTE-WINDOWS.md` para uma maquina nova e `docs/INSTALADOR.md` para updater e verificacao manual.

## Updater e primeira execucao

O pacote inicial contem corelib, gamelib, modulelib, startup, game_shaders, client_locales, client_styles, client_background, client_topmenu, updater, fontes, estilos, imagens da interface e certificados. O primeiro uso precisa de internet para baixar dados do jogo, sprites, sons, mods e demais modulos. Cancelar o primeiro download fecha o cliente; abrir novamente tenta a atualizacao.

O build publica em `files/binaries/windows/x86/Clientex86.exe` e `files/binaries/windows/x64/Clientex64.exe`; `files/Crystal.exe` permanece como compatibilidade para clientes x64 antigos. Os recursos completos permanecem tambem na raiz de desenvolvimento. Nao removemos recursos compartilhados de `files/`, pois clientes existentes ainda podem precisar atualiza-los.

Execute os builds em sequencia porque `files/` e compartilhada. Antes de distribuir x86, publique manualmente a API atualizada `tools/api/updater.php` e o payload completo de `files/`. Nada e enviado ao servidor automaticamente. Os caminhos finais data/things/<version>/ e data/sounds/<version>/ e as regras estritas de hashes permanecem iguais.

## Linux e Android

A padronizacao deste passo abrange Windows. Os presets e destinos Linux/Android existentes continuam disponiveis. Linux continua com `dist/dist-linux/` e pacotes em `dist/linux-packages/` ate a organizacao especifica dessas plataformas.
