#!/usr/bin/env bash
set -euo pipefail
export CRYSTAL_PACKAGE_PRESET=linux-x64-debug
exec bash "$(dirname -- "${BASH_SOURCE[0]}")/../linux-x64-release/empacotar.sh" "$@"
