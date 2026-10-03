# Changelog

## 2026-09-12
- Configured the `linux-release` preset to emit a complete ready-to-run distribution in `dist-linux`, including the `Crystal` ELF, Lua entry files, certificate, configuration, `data`, `modules`, and `mods`.
- Pinned both the CMake compiler and the vcpkg `CC`/`CXX` environment for Linux releases to GCC/G++ 13, so clean WSL sessions do not select an older default compiler without C++20 `<format>` support.
- Added the Linux `Crystal` binary to the common repository `files` updater payload while preserving the existing Windows and Android release artifacts and preventing Debug builds from replacing published executables.
- Enabled updater binary delivery for both `X11-GLX` and `X11-EGL`, using the extensionless `Crystal` Linux executable.

## 2026-09-09
- Removed the public "Change updater URL" button from the updater window while preserving automatic update checks and downloads.

## 2026-09-08
- Simplified the desktop login build label to the client version and build date, hiding revision, branch, compiler and architecture details from public Windows clients.
- Hid the build revision, compiler and architecture label on mobile login screens while retaining it for desktop diagnostics, and advanced the Android release to version 1.3 (code 4) so installed 1.2 clients can receive it.
- Extended the bundled desktop Discord Rich Presence payload with `Discord` and `Cadastro` buttons linked to the Crystal community invite and website; incomplete label/URL pairs are safely omitted.
- Reworked Windows executable self-updates to use numeric filenames only while the running binary is locked, then promote the downloaded client back to the stable `Crystal.exe` path and remove stale updater executables so shortcuts remain valid on every computer.
- Made the installer always create Start Menu and Desktop shortcuts targeting the stable `Crystal.exe` name, with a separately installed `Crystal.ico` so executable updates cannot change shortcut branding.
- Disabled CMake precompiled headers for Android's per-file native build, preventing missing `std::shared_ptr` declarations and the resulting `PacketPlayerPtr`/`PacketRecorderPtr` compilation failures.
- Fixed the desktop Discord Rich Presence startup by propagating the enabled RPC compile definition to the final executable target that owns `main.cpp`.
- Changed the always-run CMake updater synchronization to execute after the client target and publish `init.lua`, `data`, `modules`, `mods`, the real Windows Release `Crystal.exe`, and any latest staged Android package into `files`; Debug executables, DLLs and server-only paperdoll examples remain excluded.
- Configured the updater API to serve `Crystal.exe` only to the actual Visual Studio `WIN32-WGL` client, keeping unrelated Windows, Linux and Android binary mappings disabled.

## 2026-09-07
- Added a local OpenAL Soft overlay port that replaces a nested C++20 ranges view rejected by Visual Studio 2026, preserving the existing build and distribution directory layout.
- Prepared client-side gold formatting for messages beginning with `Loot Premium`; the current server implementation keeps Premium drops in the standard combined loot notification.

## 2026-09-01
- Added native Android APK self-update support with server-side version metadata, HTTPS-only downloads, SHA-256 validation, package/version validation, user-approved unknown-source permission and Android package-installer handoff.
- Made every Android release build publish `Crystal.apk` and `android-version.json` into the VPS updater payload while preserving those artifacts during later desktop payload synchronization.
- Disabled CMake unity compilation for Android to prevent WSL out-of-memory termination on large native translation units.
- Documented the single-command Windows build and updater packaging workflow using `tools/compilar-e-empacotar.ps1 -Build`, including the automatically synchronized repository `files` output.
- Added an always-run CMake updater-payload target that recreates the repository `files` directory from `init.lua`, `data`, `modules`, and `mods` after every desktop or Android native build.
- Fixed the Android JNI shutdown crash by keeping the process-lifetime manager reference out of static destruction and by using the callback-local `JNIEnv` only on its owning thread.
- Disabled the bundled game bot in source, packaged desktop distribution and installed client; removed automatic loading, blocked manual initialization and guarded profile reloads when the module is absent.
- Packaged the current Mozilla CA bundle in Android `data.zip` and configured IXWebSocket to use it for verified HTTPS, allowing normal server certificate renewals without updater failures.
- Guarded startup clicks when `game_interface` is not loaded, preventing the updater error dialog from causing a secondary Lua exception.
- Bundled the official legacy `discord-rpc` source and integrated it into CMake, enabling desktop Rich Presence without a separate installation while keeping Android excluded.

## 2026-08-31
- Added `TUTORIAL-ATUALIZAR-E-BUILDAR-ANDROID.md` with the verified Windows/WSL workflow for backups, source synchronization, complete `data.zip` regeneration, ARM64 APK builds, ADB installation, cache clearing and diagnostics.
- Routed Android joystick movement through the guarded keyboard walking routine, preventing the 20 ms joystick refresh from flooding the server with walk packets and disconnecting the player.
- Increased the adaptive global mobile UI scale to 2.0x on landscape displays at least 900 px high, improving menus and touch buttons while retaining 1.0x on 720p devices.
- Made the default mobile HUD scale adaptive: 1.0x below 900 px landscape height and 1.5x at 900 px or above, covering both Galaxy A12 and Moto G73 layouts.
- Added a branded Crystal loading overlay so first-run extraction no longer appears as a prolonged black screen on slower phones.
- Renamed the Android application and generated APK to `Crystal`; applied the official saved Crystal assets as separate launcher and loading logos.
- Added a JNI readiness callback that dismisses the loading overlay only after `init.lua` has executed.

## 2026-08-30
- Regenerated the Android LuaJIT C++ wrapper with `luajit.h`; this prevents the ARM64 build from selecting incompatible Lua 5.2 environment APIs while linking LuaJIT 5.1.
- Updated the Android LuaJIT pin from the incompatible 2017 revision to the 2026 revision used by the project's vcpkg baseline, fixing ARM64 stack and environment crashes with NDK 29.
- Restored the upstream `LuaInterface` environment initialization after confirming the crash originated in the outdated LuaJIT binary rather than the interface routine.
- Added `config.ini` to the Android `data.zip` generation paths so the public graphics and font configuration is available at runtime.

## 2026-08-29
- Rebuilt `cmake/icon/otcicon.ico` from the supplied 1024x1024 artwork with embedded 16, 24, 32, 48, 64, 128, and 256 pixel layers for sharp Windows, shortcut, executable, and installer rendering.
- Added `tools/compilar-e-empacotar.ps1` to compile Release and generate separate desktop-client and VPS-updater packages.
- Added automatic preservation of the previous `dist` directory before each new package is generated.
- Added SHA-256 hashes, resource file counts, required-path validation, and a packaging report.
- Made `tools/api/updater.php` use the packaged Linux-compatible `api/` and `files/` sibling layout.
- Added JSON input, directory, iterator, and checksum-cache error handling to prevent opaque HTTP 500 responses.
- Assigned unique MSVC object names to the framework and client `luafunctions.cpp` files, preventing warning MSB8027 and unsafe incremental output collisions.
- Changed packaging to use an already compiled Release by default; optional compilation is available through `-Build`.
- Added all Release runtime DLLs to desktop and VPS packages so the dynamically linked client can start by double-clicking.
- Excluded the `game_paperdolls/server` C++ integration examples from runtime packages while preserving the Lua client module.
- Replaced the Windows executable icon with the icon extracted from the reference 15.24 client.
- Added an Inno Setup definition and `tools/criar-instalador.ps1` to generate a per-user Crystal Client installer with Start Menu and optional desktop shortcuts.
- Added `TUTORIAL-COMPILAR-DO-ZERO.md`, a drive-independent Windows recovery guide with official client/server repository links, environment installation, build, packaging, installer, updater, backup, and diagnostics commands.
- Configured Windows CMake Release builds to emit `dist/CrystalClient/Crystal.exe` directly and copy runtime resources beside it, removing the separate packaging step for normal client builds.

## 2026-02-04
- Added OTML alias resolution so `.otui` files can declare variables (e.g. `&primaryColor`) and reference them as `$primaryColor`, improving theme consistency and readability.

## 05-12-2023
### Breaking API Changes
- `UIWidget` property `qr-code` & `qr-code-border` replaced with `UIQrCode` properties `code` & `code-border`
- `image-source-base64` replaced with `image-source: base64:/path/to/image`
- `#include "shadermanager.h"` moved to `#include <framework/graphics/shadermanager.h>`
# Correção do build Android sem Unity

- Incluída a dependência explícita de `ResourceManager` no gravador de pacotes. Antes, essa dependência era fornecida indiretamente pelos arquivos Unity e impedia a compilação Android com baixo consumo de memória.
- Incluído o cabeçalho padrão de inteiros no gerenciador Android para declarar com segurança os códigos de versão de 64 bits.
