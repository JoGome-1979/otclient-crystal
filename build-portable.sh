#!/usr/bin/env bash
set -euo pipefail
task_jobs="${CRYSTAL_JOBS:-10}"
build_type="${CRYSTAL_BUILD_TYPE:-Release}"
case "$build_type" in Release|Debug) ;; *) exit 2 ;; esac
test -f /source/CMakeLists.txt
mkdir -p /workspace/src /workspace/downloads /export/client /export/updater
# Only this generated container copy is synchronized/deleted; /source is read-only.
rsync -a --delete --exclude=.git --exclude=.vs --exclude=.vscode \
  --exclude=build --exclude=out --exclude=files --exclude=dist --exclude=dist-linux \
  --exclude=vcpkg_installed --exclude=android-output --exclude=android/.gradle \
  --exclude=android/.cxx --exclude=android/app/build \
  /source/ /workspace/src/
export VCPKG_DOWNLOADS=/workspace/downloads
export VCPKG_MAX_CONCURRENCY="$task_jobs"
cmake -S /workspace/src -B /workspace/native -G Ninja \
  -DCMAKE_BUILD_TYPE="$build_type" \
  -DCMAKE_C_COMPILER=/usr/bin/gcc-13 -DCMAKE_CXX_COMPILER=/usr/bin/g++-13 \
  -DCMAKE_TOOLCHAIN_FILE=/opt/vcpkg/scripts/buildsystems/vcpkg.cmake \
  -DVCPKG_TARGET_TRIPLET=x64-linux -DVCPKG_HOST_TRIPLET=x64-linux \
  -DVCPKG_INSTALLED_DIR=/workspace/vcpkg_installed -DVCPKG_BUILD_TYPE=release \
  -DOPTIONS_ENABLE_IPO=OFF -DSPEED_UP_BUILD_UNITY=OFF \
  -DTOGGLE_DIRECTX=OFF -DOTCLIENT_BUILD_TESTS=OFF \
  '-DCMAKE_EXE_LINKER_FLAGS=-static-libstdc++ -static-libgcc'
cmake --build /workspace/native --parallel "$task_jobs"
runtime=/workspace/src/dist/dist-linux
if test "$build_type" = Debug; then runtime=/workspace/native/bin; fi
binary="$runtime/Crystal"
test -f "$binary"
# Export current resources only; preserve the container's incremental build/cache.
rsync -a --delete "$runtime/" /export/client/
chmod +x /export/client/Crystal
if test "$build_type" = Release; then
  cp "$binary" /export/updater/Crystal
  chmod +x /export/updater/Crystal
fi
readelf --version-info "$binary" > /export/elf-versions.txt
ldd "$binary" > /export/dependencies.txt
# Enforce the declared glibc floor and detect unbundled C++ runtime dependencies.
maximum_glibc="$(grep -oE 'GLIBC_[0-9.]+' /export/elf-versions.txt | sed 's/GLIBC_//' | sort -Vu | tail -n 1)"
if test -z "$maximum_glibc" || test "$(printf '%s\n' "$maximum_glibc" 2.35 | sort -V | tail -n 1)" != 2.35; then
  echo "ERROR: unexpected glibc requirement: $maximum_glibc (maximum allowed: 2.35)" >&2
  exit 1
fi
if grep -Eq 'not found|libstdc\+\+\.so|libgcc_s\.so' /export/dependencies.txt; then
  echo 'ERROR: unresolved libraries or non-static C++ runtime; inspect dependencies.txt.' >&2
  exit 1
fi
printf 'x86_64, glibc >= %s; needs system X11/OpenGL.\n' "$maximum_glibc" > /export/compatibility.txt
chown -R "${EXPORT_UID}:${EXPORT_GID}" /export
