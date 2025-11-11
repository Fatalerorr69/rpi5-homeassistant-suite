#!/bin/bash
# Comprehensive post-install setup menu
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

show_menu() {
    clear
    echo "=========================================="
    echo "🏠 HOME ASSISTANT SUITE - POST-INSTALL"
    echo "=========================================="
    echo "1) Příprava runtime adresářů"
    echo "2) Nastavení file explorer (Samba/SFTP)"
    echo "3) Nastavení údržby (log rotation, cleanup)"
    echo "4) Nastavení monitoringu a health checks"
    echo "5) Analýza disk utilizace"
    echo "6) Nastavení externího úložiště"
    echo "7) Všechny kroky (doporučeno pro novou instalaci)"
    echo "8) Odhlášení (bez akcí)"
    echo "=========================================="
}

runtime_setup() {
    echo "Příprava runtime adresářů..."
    mkdir -p "$REPO_ROOT/config/packages"
    mkdir -p "$REPO_ROOT/config/zigbee2mqtt"
    mkdir -p "$REPO_ROOT/config/mosquitto"
    mkdir -p "$REPO_ROOT/config/node-red"
    mkdir -p "$REPO_ROOT/config/portainer"
    mkdir -p "$REPO_ROOT/backups"
    
    # Kopírovat příklady, pokud existují
    if [ -d "$REPO_ROOT/TEMPLATES/package_examples" ]; then
        cp -a "$REPO_ROOT/TEMPLATES/package_examples"/* "$REPO_ROOT/config/packages/" 2>/dev/null || true
    fi
    
    echo "✅ Runtime adresáře připraveny"
    echo "Obsah: $(ls -d $REPO_ROOT/config/*/ | wc -l) podsložek"
}

run_step() {
    local script="$1"
    if [ -x "$script" ]; then
        bash "$script"
    else
        echo "❌ Skript $script není spustitelný"
        chmod +x "$script"
        bash "$script"
    fi
}

main() {
    while true; do
        show_menu
        read -p "Vyberte [1-8]: " choice
        
        case "$choice" in
            1)
                runtime_setup
                read -p "Stiskněte Enter..."
                ;;
            2)
                run_step "$REPO_ROOT/POST_INSTALL/setup_file_explorer.sh"
                read -p "Stiskněte Enter..."
                ;;
            3)
                run_step "$REPO_ROOT/POST_INSTALL/setup_maintenance.sh"
                read -p "Stiskněte Enter..."
                ;;
            4)
                run_step "$REPO_ROOT/POST_INSTALL/setup_monitoring.sh"
                read -p "Stiskněte Enter..."
                ;;
            5)
                run_step "$REPO_ROOT/scripts/storage_analyzer.sh"
                read -p "Stiskněte Enter..."
                ;;
            6)
                run_step "$REPO_ROOT/scripts/mount_storage.sh" list
                read -p "Stiskněte Enter..."
                ;;
            7)
                echo "Spouštím všechny post-install kroky..."
                runtime_setup
                run_step "$REPO_ROOT/POST_INSTALL/setup_file_explorer.sh" || true
                run_step "$REPO_ROOT/POST_INSTALL/setup_maintenance.sh" || true
                run_step "$REPO_ROOT/POST_INSTALL/setup_monitoring.sh" || true
                echo ""
                echo "✅ Post-install setup dokončen!"
                read -p "Stiskněte Enter..."
                ;;
            8)
                echo "Odchod bez akcí"
                exit 0
                ;;
            *)
                echo "Neplatná volba"
                sleep 2
                ;;
        esac
    done
}

main "$@"
