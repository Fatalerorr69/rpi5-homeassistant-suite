#!/bin/bash
# MASTER INSTALAČNÍ SKRIPT - RPi5 Home Assistant Suite - OPRAVENÁ VERZE

set -euo pipefail

# Barvy
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +%T)]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +%T)]${NC} $1"; }
err() { echo -e "${RED}[$(date +%T)]${NC} $1"; }

# Funkce pro kontrolu a opravu instalace
check_hass_supervised() {
    if ! command -v ha &> /dev/null; then
        warn "Home Assistant Supervised není nainstalován, spouštím instalaci..."
        bash INSTALLATION/install_ha_complete.sh
    else
        log "Home Assistant Supervised je nainstalován"
    fi
}

# Hlavní menu
show_menu() {
    echo "=========================================="
    echo "🏠 RPi5 HOME ASSISTANT SUITE - INSTALACE"
    echo "=========================================="
    echo "1) Kompletní instalace (doporučeno)"
    echo "2) Pouze Home Assistant Supervised"
    echo "3) Pouze MHS35 displej"
    echo "4) Diagnostika systému"
    echo "5) Optimalizace úložišť"
    echo "6) Oprava problémů"
    echo "7) Nastavení NAS"
    echo "8) Ukončit"
    echo "=========================================="
}

main() {
    while true; do
        show_menu
        read -p "Vyberte možnost [1-8]: " choice
        
        case $choice in
            1)
                log "Spouštím KOMPLETNÍ INSTALACI..."
                bash INSTALLATION/install_ha_complete.sh
                bash POST_INSTALL/install_addons.sh
                bash POST_INSTALL/setup_gaming_services.sh
                bash POST_INSTALL/setup_nas.sh
                ;;
            2)
                log "Instalace HOME ASSISTANT SUPERVISED..."
                bash INSTALLATION/install_ha_complete.sh
                ;;
            3)
                log "Instalace MHS35 DISPLEJE..."
                bash HARDWARE/one_step_fullsuite_starkos_mhs35_interactive_auto.sh
                ;;
            4)
                log "DIAGNOSTIKA systému..."
                bash DIAGNOSTICS/quick_scan.sh
                python3 DIAGNOSTICS/device_structure_scan.py
                ;;
            5)
                log "OPTIMALIZACE úložišť..."
                python3 STORAGE/storage_analyzer.py
                python3 STORAGE/storage_optimizer.py
                ;;
            6)
                log "OPRAVA problémů..."
                check_hass_supervised
                python3 DIAGNOSTICS/repair_homeassistant.py
                ;;
            7)
                log "NASTAVENÍ NAS..."
                bash POST_INSTALL/setup_nas.sh
                ;;
            8)
                log "Ukončuji..."
                exit 0
                ;;
            *)
                err "Neplatná volba!"
                ;;
        esac
        
        echo "" && read -p "Pokračovat stiskem Enter..."
    done
}

main "$@"