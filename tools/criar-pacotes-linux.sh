#!/usr/bin/env bash
set -euo pipefail
umask 022
source_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
version=1.0.0
binary="$source_root/dist/dist-linux/Crystal"
output="$source_root/dist/linux-packages"
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
      echo 'Uso: tools/criar-pacotes-linux.sh [--version 1.0.0] [--binary /caminho/Crystal] [--formats portable,deb,rpm] [--output /pasta]'
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
LC_ALL=C readelf -h "$binary" | grep -q 'Advanced Micro Devices X86-64' || {
  echo 'Este empacotador suporta somente Linux x86-64.' >&2; exit 1;
}
versions=$(LC_ALL=C readelf --version-info "$binary")
glibc_floor=$(printf '%s\n' "$versions" | grep -oE 'GLIBC_[0-9.]+' | sed 's/GLIBC_//' | sort -Vu | tail -n 1)
[[ -n "$glibc_floor" ]] || { echo 'Nao foi possivel determinar a versao minima da glibc.' >&2; exit 1; }
mkdir -p -- "$output"
output=$(cd -- "$output" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/crystal-linux-packages.XXXXXXXX")
trap 'rm -rf -- "$work"' EXIT
cmake "-DSOURCE_ROOT:PATH=$source_root" "-DOUTPUT_ROOT:PATH=$work/CrystalClient" \
      "-DPLATFORM=linux" "-DBINARY_FILE:FILEPATH=$binary" -P "$source_root/cmake/StageClientBootstrap.cmake"
seed="$work/CrystalClient"
rm -- "$seed/.crystal-installer-stage"
# Strip only the packaged copy; retain the original binary and debug symbols.
strip --strip-debug "$seed/Crystal"
find "$seed" -type d -exec chmod 755 {} +
find "$seed" -type f -exec chmod 644 {} +
chmod 755 "$seed/Crystal"
seed_id="$version:$(sha256sum "$seed/Crystal" | cut -d ' ' -f 1):$(sha256sum "$seed/init.lua" | cut -d ' ' -f 1)"
cat > "$work/compatibility.txt" <<COMPAT
Crystal Client $version — Linux x86-64
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
    install -m 755 "$source_root/tools/linux/crystal-client" "$portable/crystal-client"
    printf '%s\n' "$seed_id" > "$portable/seed.id"
    cp "$work/compatibility.txt" "$portable/LEIA-ME.txt"
    tar -czf "$output/CrystalClient-$version-linux-x86_64-glibc$glibc_floor.tar.gz" -C "$work/portable" "CrystalClient-$version"
    continue
  fi
  payload="$work/$format-root"
  mkdir -p "$payload/usr/lib/crystal-client" "$payload/usr/bin" "$payload/usr/share/applications" "$payload/usr/share/pixmaps" "$payload/usr/share/doc/crystal-client"
  cp -R "$seed" "$payload/usr/lib/crystal-client/client"
  printf '%s\n' "$seed_id" > "$payload/usr/lib/crystal-client/seed.id"
  install -m 755 "$source_root/tools/linux/crystal-client" "$payload/usr/bin/crystal-client"
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
set(CPACK_PACKAGE_FILE_NAME "crystal-client-$version-linux-x86_64")
set(CPACK_PACKAGE_VENDOR "Crystal Server")
set(CPACK_PACKAGE_CONTACT "Crystal Server")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Crystal Client com updater por usuario")
set(CPACK_PACKAGE_DESCRIPTION "Crystal Client com atualizacao automatica em uma pasta gravavel por usuario.")
set(CPACK_PACKAGE_VERSION "$version")
set(CPACK_PACKAGE_DIRECTORY "$output")
set(CPACK_PACKAGING_INSTALL_PREFIX "/")
set(CPACK_INSTALLED_DIRECTORIES "$payload;/")
set(CPACK_DEBIAN_PACKAGE_NAME "crystal-client")
set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "amd64")
set(CPACK_DEBIAN_PACKAGE_SECTION "games")
set(CPACK_DEBIAN_FILE_NAME "DEB-DEFAULT")
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
set(CPACK_DEBIAN_PACKAGE_DEPENDS "bash, util-linux")
set(CPACK_RPM_PACKAGE_NAME "crystal-client")
set(CPACK_RPM_PACKAGE_ARCHITECTURE "x86_64")
set(CPACK_RPM_PACKAGE_LICENSE "MIT")
set(CPACK_RPM_FILE_NAME "RPM-DEFAULT")
set(CPACK_RPM_PACKAGE_REQUIRES "bash, util-linux, glibc >= $glibc_floor")
include(CPack)
CPACK
  if [[ "$format" == deb ]]; then generator=DEB; else generator=RPM; fi
  cmake -S "$work/meta-$format" -B "$work/meta-$format/build"
  cpack --config "$work/meta-$format/build/CPackConfig.cmake" -G "$generator" -B "$work/packages-$format"
  if [[ "$format" == deb ]]; then
    cp "$work/packages-$format/crystal-client_${version}_amd64.deb" "$output/"
  else
    cp "$work/packages-$format/crystal-client-${version}-1.x86_64.rpm" "$output/"
  fi
done
cp "$work/compatibility.txt" "$output/compatibility-$version.txt"
for format in "${selected_formats[@]}"; do
  case "$format" in
    portable) artifact="$output/CrystalClient-$version-linux-x86_64-glibc$glibc_floor.tar.gz";;
    deb) artifact="$output/crystal-client_${version}_amd64.deb";;
    rpm) artifact="$output/crystal-client-${version}-1.x86_64.rpm";;
  esac
  [[ -f "$artifact" ]] || { echo "Pacote esperado nao foi gerado: $artifact" >&2; exit 1; }
  sha256sum "$artifact" > "$artifact.sha256"
  echo "Gerado: $artifact"
done

# Reduce only the standard generated Linux distribution after successful packaging.
# Preserve the complete copy (including its original binary) for rollback/debugging.
if [[ "$binary" == "$source_root/dist/dist-linux/Crystal" ]]; then
  full_backup="$source_root/build/distribution-full/linux-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$(dirname "$full_backup")"
  mv -- "$source_root/dist/dist-linux" "$full_backup"
  mkdir -p "$source_root/dist/dist-linux"
  cp -R -- "$seed/." "$source_root/dist/dist-linux/"
  chmod +x "$source_root/dist/dist-linux/Crystal"
  echo "Distribuicao completa preservada em: $full_backup"
fi
