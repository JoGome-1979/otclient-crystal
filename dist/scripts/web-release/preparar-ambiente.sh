#!/usr/bin/env bash
set -euo pipefail
sdk_version=4.0.23
source_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
sdk_root=${EMSDK:-$HOME/emsdk}
vcpkg_root=${VCPKG_ROOT:-$HOME/vcpkg}
for tool in python3 git curl cmake ninja gcc-13 g++-13 pkg-config autoconf automake libtoolize nasm bison flex zip unzip tar; do
  command -v "$tool" >/dev/null || {
    echo "Falta $tool. No Ubuntu/WSL instale: sudo apt install git curl ca-certificates cmake ninja-build gcc-13 g++-13 python3 python3-venv python3-pip pkg-config autoconf automake autoconf-archive libtool libtool-bin nasm bison flex zip unzip tar" >&2
    exit 1
  }
done
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
python3 -I -m venv --symlinks "$work/python-check"
"$work/python-check/bin/python" -m pip --version
if [[ ! -f "$sdk_root/emsdk" ]]; then
  git clone --depth 1 https://github.com/emscripten-core/emsdk.git "$sdk_root"
fi
(cd "$sdk_root" && ./emsdk install "$sdk_version" && ./emsdk activate "$sdk_version")
if [[ ! -f "$vcpkg_root/scripts/buildsystems/vcpkg.cmake" ]]; then
  git clone https://github.com/microsoft/vcpkg.git "$vcpkg_root"
  baseline=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["builtin-baseline"])' "$source_root/browser/vcpkg.json")
  git -C "$vcpkg_root" checkout "$baseline"
fi
if [[ ! -x "$vcpkg_root/vcpkg" ]]; then
  "$vcpkg_root/bootstrap-vcpkg.sh" -disableMetrics
fi
export EMSDK="$sdk_root" VCPKG_ROOT="$vcpkg_root"
cmake -P "$source_root/cmake/WebEnvironment.cmake"
echo "Ambiente web pronto. Da raiz: cmake --preset web-release"
