#!/usr/bin/env bash
set -euo pipefail
umask 077
if [[ $(id -u) -eq 0 ]]; then
  echo 'Abra o Crystal como seu usuario normal, sem sudo.' >&2
  exit 1
fi
script_dir=$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
if [[ -f "$script_dir/client/Crystal" ]]; then
  seed_root=$script_dir
else
  seed_root=/usr/lib/crystal-client
fi
seed="$seed_root/client"
[[ -f "$seed/Crystal" && -f "$seed_root/seed.id" ]] || {
  echo "Pacote inicial nao encontrado: $seed" >&2; exit 1;
}
data_root="${XDG_DATA_HOME:-$HOME/.local/share}/crystal-client"
config_root="${XDG_CONFIG_HOME:-$HOME/.config}/crystal-client"
runtime="$data_root/client"
custom_config=false
for argument in "$@"; do
  if [[ "$argument" == --user-dir=* ]]; then custom_config=true; fi
done
mkdir -p -- "$data_root" "$runtime"
[[ -w "$data_root" && -w "$runtime" ]] || {
  echo "Pasta do cliente sem permissao de escrita: $runtime" >&2; exit 1;
}
# Serialize seed installation; release the lock before launching the client.
exec 9>"$data_root/seed.lock"
flock 9
seed_id=$(cat -- "$seed_root/seed.id")
installed_seed=$(cat -- "$data_root/seed.id" 2>/dev/null || true)
if [[ "$installed_seed" != "$seed_id" || ! -f "$runtime/Crystal" || ! -f "$runtime/init.lua" ]]; then
  # cp without -p/-a creates user-owned files, even when the seed belongs to root.
  cp -R -- "$seed/." "$runtime/"
  chmod u+rwx -- "$runtime/Crystal"
  printf '%s\n' "$seed_id" > "$data_root/seed.id.tmp"
  mv -- "$data_root/seed.id.tmp" "$data_root/seed.id"
fi
flock -u 9
exec 9>&-
if [[ "$custom_config" == false ]]; then
  mkdir -p -- "$config_root"
  [[ -w "$config_root" ]] || {
    echo "Pasta de configuracoes sem permissao de escrita: $config_root" >&2; exit 1;
  }
  # Preserve existing OTC profiles on first migration; never overwrite new settings.
  if [[ ! -e "$config_root/.legacy-migrated" ]]; then
    if [[ -d "$HOME/.Crystal" && ! -f "$config_root/config.otml" ]]; then
      cp -R -- "$HOME/.Crystal/." "$config_root/"
    fi
    touch -- "$config_root/.legacy-migrated"
  fi
  set -- "--user-dir=$config_root" "$@"
fi
cd -- "$runtime"
exec "$runtime/Crystal" "$@"
