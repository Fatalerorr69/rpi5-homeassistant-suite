#!/usr/bin/env bash
set -euo pipefail

echo "📦 Instalace doplňků HA..."
declare -a addons=("core_ssh" "core_configurator" "core_samba" "a0d7b954_portainer" "a0d7b954_vscode" "hassio_vmm" "local_backupmgr")
for addon in "${addons[@]}"; do
    echo "→ Instalace $addon..."
    ha addons install "$addon" || echo "❌ Chyba instalace $addon"
    ha addons start "$addon" || echo "⚠️ Není možné automaticky spustit $addon"
done
