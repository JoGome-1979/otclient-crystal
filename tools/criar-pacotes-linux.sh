#!/usr/bin/env bash
set -euo pipefail
exec bash "$(dirname -- "${BASH_SOURCE[0]}")/../dist/scripts/linux-x64-release/empacotar.sh" "$@"
