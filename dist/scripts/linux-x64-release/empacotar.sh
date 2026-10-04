#!/usr/bin/env bash
set -euo pipefail
umask 022
source_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
preset=${CRYSTAL_PACKAGE_PRESET:-linux-x64-release}
[[ "$preset" =~ ^linux-(x86|x64)-(portable-)?(release|debug)$ ]] || { echo "Preset invalido: $preset" >&2; exit 2; }
arch=${preset#linux-}; arch=${arch%%-*}
if [[ "$arch" == x86 ]]; then
  elf_machine='Intel 80386'; elf_class=ELF32; archive_arch=x86; deb_arch=i386; rpm_arch=i686
else
  elf_machine='Advanced Micro Devices X86-64'; elf_class=ELF64; archive_arch=x86_64; deb_arch=amd64; rpm_arch=x86_64
fi
package_root="$source_root/dist/$preset"
version=1.0.0
binary="$package_root/Crystal"
output="$source_root/dist/instalador/$preset"
formats=portable,deb
while (($#)); do
  case "$1" in
    --version|--binary|--output|--formats)
      (($# >= 2)) || { echo "Valor ausente para $1" >&2; exit 2; }
      case "$1" in
        --version) version=$2;; --binary) binary=$2;; --output) output=$2;; --formats) formats=$2;;
      esac
      shift 2;;
    --help|-h)
      echo 'Uso: dist/scripts/<preset>/empacotar.sh [--version 1.0.0] [--binary /caminho/Crystal] [--formats portable,deb,rpm] [--output /pasta]'
      echo 'Padrao: portatil + DEB. RPM exige rpmbuild. O binario escolhido define a compatibilidade com glibc.'
      exit 0;;
    *) echo "Opcao desconhecida: $1" >&2; exit 2;;
  esac
done
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Versao invalida' >&2; exit 2; }
[[ -f "$binary" ]] || { echo "Binario nao encontrado: $binary" >&2; exit 1; }
binary=$(readlink -f -- "$binary")
for tool in cmake cpack readelf strip tar sha256sum; do command -v "$tool" >/dev/null; done
IFS=, read -r -a selected_formats <<< "$formats"
for format in "${selected_formats[@]}"; do
  case "$format" in
    portable) ;; deb) command -v dpkg-deb >/dev/null;; rpm) command -v rpmbuild >/dev/null || { echo 'RPM requer rpmbuild (pacote rpm/rpm-build da sua distribuicao).' >&2; exit 1; };;
    *) echo "Formato desconhecido: $format" >&2; exit 2;;
  esac
done
elf_header=$(LC_ALL=C readelf -h "$binary")
if ! grep -q "$elf_machine" <<< "$elf_header" || ! grep -q "$elf_class" <<< "$elf_header"; then
  echo "O binario nao corresponde ao preset $preset ($elf_class, $elf_machine)." >&2; exit 1
fi
versions=$(LC_ALL=C readelf --version-info "$binary")
glibc_floor=$(printf '%s\n' "$versions" | grep -oE 'GLIBC_[0-9.]+' | sed 's/GLIBC_//' | sort -Vu | tail -n 1)
[[ -n "$glibc_floor" ]] || { echo 'Nao foi possivel determinar a versao minima da glibc.' >&2; exit 1; }
mkdir -p -- "$output"
output=$(cd -- "$output" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/crystal-linux-packages.XXXXXXXX")
trap 'rm -rf -- "$work"' EXIT
[[ -f "$package_root/.crystal-distribution" && -f "$package_root/init.lua" && -f "$package_root/modules/updater/updater.otmod" ]] || {
  echo "Distribuicao minima ausente. Execute: cmake --preset $preset; cmake --build build/$preset -j 10" >&2; exit 1;
}
seed="$work/CrystalClient"
mkdir -p "$seed"
cp -R -- "$package_root/." "$seed/"
rm -f -- "$seed/.crystal-distribution"
cp -- "$binary" "$seed/Crystal"
# Preserve previous downloadable packages before replacing their names.
backup_dir="$source_root/backups/$(date +%Y%m%d-%H%M%S)-linux-package-$preset-$$"
for artifact in "$output"/*; do
  [[ -f "$artifact" ]] || continue
  mkdir -p "$backup_dir"
  cp -p -- "$artifact" "$backup_dir/"
done
# Strip only the packaged copy; retain the original binary and debug symbols.
if [[ "$preset" == *-release ]]; then strip --strip-debug "$seed/Crystal"; fi
find "$seed" -type d -exec chmod 755 {} +
find "$seed" -type f -exec chmod 644 {} +
chmod 755 "$seed/Crystal"
seed_id="$version:$(sha256sum "$seed/Crystal" | cut -d ' ' -f 1):$(sha256sum "$seed/init.lua" | cut -d ' ' -f 1)"
cat > "$work/compatibility.txt" <<COMPAT
Crystal Client $version — Linux $arch
Requer glibc >= $glibc_floor. O formato do pacote nao altera essa exigencia.
Bibliotecas compartilhadas exigidas pelo executavel:
$(LC_ALL=C readelf -d "$binary" | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p')
Inicie por crystal-client, sem sudo. O updater grava em uma copia pertencente ao usuario.
Cliente: XDG_DATA_HOME/crystal-client/client (padrao ~/.local/share/crystal-client/client).
Configuracoes: XDG_CONFIG_HOME/crystal-client (padrao ~/.config/crystal-client).
COMPAT
for format in "${selected_formats[@]}"; do
  if [[ "$format" == portable ]]; then
    portable="$work/portable/CrystalClient-$version"
    mkdir -p "$portable"
    cp -R "$seed" "$portable/client"
    install -m 755 "$source_root/dist/scripts/linux-x64-release/crystal-client.sh" "$portable/crystal-client"
    printf '%s\n' "$seed_id" > "$portable/seed.id"
    cp "$work/compatibility.txt" "$portable/LEIA-ME.txt"
    tar -czf "$output/CrystalClient-$version-linux-$archive_arch-glibc$glibc_floor.tar.gz" -C "$work/portable" "CrystalClient-$version"
    continue
  fi
  payload="$work/$format-root"
  mkdir -p "$payload/usr/lib/crystal-client" "$payload/usr/bin" "$payload/usr/share/applications" "$payload/usr/share/pixmaps" "$payload/usr/share/doc/crystal-client"
  cp -R "$seed" "$payload/usr/lib/crystal-client/client"
  printf '%s\n' "$seed_id" > "$payload/usr/lib/crystal-client/seed.id"
  install -m 755 "$source_root/dist/scripts/linux-x64-release/crystal-client.sh" "$payload/usr/bin/crystal-client"
  install -m 644 "$source_root/data/images/clienticon.png" "$payload/usr/share/pixmaps/crystal-client.png"
  cp "$work/compatibility.txt" "$payload/usr/share/doc/crystal-client/compatibility.txt"
  cat > "$payload/usr/share/applications/crystal-client.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Crystal Client
Comment=Cliente Crystal com atualizacao automatica
Exec=crystal-client
Icon=crystal-client
Terminal=false
Categories=Game;
DESKTOP
  mkdir -p "$work/meta-$format"
  cat > "$work/meta-$format/CMakeLists.txt" <<CPACK
cmake_minimum_required(VERSION 3.24)
project(CrystalPackage NONE)
set(CPACK_PACKAGE_NAME "crystal-client")
set(CPACK_PACKAGE_FILE_NAME "crystal-client-$version-linux-$archive_arch")
set(CPACK_PACKAGE_VENDOR "Crystal Server")
set(CPACK_PACKAGE_CONTACT "Crystal Server")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Crystal Client com updater por usuario")
set(CPACK_PACKAGE_DESCRIPTION "Crystal Client com atualizacao automatica em uma pasta gravavel por usuario.")
set(CPACK_PACKAGE_VERSION "$version")
set(CPACK_PACKAGE_DIRECTORY "$output")
set(CPACK_PACKAGING_INSTALL_PREFIX "/")
set(CPACK_INSTALLED_DIRECTORIES "$payload;/")
set(CPACK_DEBIAN_PACKAGE_NAME "crystal-client")
set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "$deb_arch")
set(CPACK_DEBIAN_PACKAGE_SECTION "games")
set(CPACK_DEBIAN_FILE_NAME "DEB-DEFAULT")
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
set(CPACK_DEBIAN_PACKAGE_DEPENDS "bash, util-linux")
set(CPACK_RPM_PACKAGE_NAME "crystal-client")
set(CPACK_RPM_PACKAGE_ARCHITECTURE "$rpm_arch")
set(CPACK_RPM_PACKAGE_LICENSE "MIT")
set(CPACK_RPM_FILE_NAME "RPM-DEFAULT")
set(CPACK_RPM_PACKAGE_REQUIRES "bash, util-linux, glibc >= $glibc_floor")
include(CPack)
CPACK
  if [[ "$format" == deb ]]; then generator=DEB; else generator=RPM; fi
  cmake -S "$work/meta-$format" -B "$work/meta-$format/build"
  cpack --config "$work/meta-$format/build/CPackConfig.cmake" -G "$generator" -B "$work/packages-$format"
  if [[ "$format" == deb ]]; then
    cp "$work/packages-$format/crystal-client_${version}_${deb_arch}.deb" "$output/"
  else
    cp "$work/packages-$format/crystal-client-${version}-1.${rpm_arch}.rpm" "$output/"
  fi
done
cp "$work/compatibility.txt" "$output/compatibility-$version.txt"
for format in "${selected_formats[@]}"; do
  case "$format" in
    portable) artifact="$output/CrystalClient-$version-linux-$archive_arch-glibc$glibc_floor.tar.gz";;
    deb) artifact="$output/crystal-client_${version}_${deb_arch}.deb";;
    rpm) artifact="$output/crystal-client-${version}-1.${rpm_arch}.rpm";;
  esac
  [[ -f "$artifact" ]] || { echo "Pacote esperado nao foi gerado: $artifact" >&2; exit 1; }
  sha256sum "$artifact" > "$artifact.sha256"
  echo "Gerado: $artifact"
done

