#!/bin/bash
set -euo pipefail

# Barvy
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
err() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }

check_ha_cli() {
    if ! command -v ha &> /dev/null; then
        err "Příkaz 'ha' není dostupný. Je Home Assistant Supervised nainstalován?"
        return 1
    fi
    return 0
}

wait_for_ha() {
    log "Čekám na připravenost Home Assistant..."
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if ha status > /dev/null 2>&1; then
            log "Home Assistant je připraven"
            return 0
        fi
        log "Pokus $attempt/$max_attempts - čekám 30 sekund..."
        sleep 30
        attempt=$((attempt + 1))
    done
    
    err "Home Assistant se nespustil v požadovaném čase"
    return 1
}

install_addon() {
    local addon=$1
    log "→ Instalace $addon..."
    
    if ha addons install $addon; then
        log "  ✅ $addon nainstalován"
        if ha addons start $addon; then
            log "  ✅ $addon spuštěn"
        else
            warn "  ⚠️ $addon nelze spustit automaticky"
        fi
    else
        err "  ❌ Chyba instalace $addon"
    fi
}

main() {
    log "📦 Instalace doplňků HA..."
    
    if ! check_ha_cli; then
        exit 1
    fi
    
    if ! wait_for_ha; then
        exit 1
    fi
    
    # Seznam doplňků pro instalaci
    local addons=(
        "core_ssh"
        "core_configurator"
        "core_samba"
        "a0d7b954_portainer"
        "a0d7b954_vscode"
        "local_backupmgr"
    )
    
    for addon in "${addons[@]}"; do
        install_addon "$addon"
    done
    
    log "✅ Doplnky nainstalovány"
    
    # Zobrazení informací
    log "🌐 Dostupné služby:"
    log "  Home Assistant: http://$(hostname -I | awk '{print $1}'):8123"
    log "  SSH: http://$(hostname -I | awk '{print $1}'):22"
    log "  Samba: \\\\$(hostname -I | awk '{print $1}')\\config"
    log "  Portainer: http://$(hostname -I | awk '{print $1}'):9000"
}

main "$@"