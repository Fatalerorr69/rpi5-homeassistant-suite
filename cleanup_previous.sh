#!/bin/bash

# ==========================================
# 🧹 CLEANUP PREVIOUS INSTALLATIONS
# ==========================================
# Skript pro kontrolu a odstranění předchozích instalací
# které by mohly způsobovat kolize
# ==========================================

set -e

# Proměnné
LOG_FILE="/home/$(whoami)/cleanup_previous.log"
USER_NAME=$(whoami)
BACKUP_DIR="/home/$(whoami)/ha_backup_$(date +%Y%m%d_%H%M%S)"

# Funkce pro logování
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Funkce pro potvrzení akce
confirm_action() {
    local message=$1
    echo ""
    echo "❓ $message"
    read -p "Pokračovat? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Akce zrušena uživatelem"
        return 1
    fi
    return 0
}

# Funkce pro vytvoření zálohy
backup_files() {
    local source=$1
    local target="$BACKUP_DIR/$(basename "$source")"
    
    if [ -e "$source" ]; then
        log "Zálohování: $source → $target"
        mkdir -p "$(dirname "$target")"
        cp -r "$source" "$target" 2>/dev/null || sudo cp -r "$source" "$target"
    fi
}

# Kontrola a odstranění Docker kontejnerů
cleanup_docker() {
    log "🔍 KONTROLA DOCKER KONTEJNERŮ"
    
    local containers=("homeassistant" "mosquitto" "zigbee2mqtt" "nodered" "portainer")
    local found_containers=()
    
    for container in "${containers[@]}"; do
        if docker ps -a --format "table {{.Names}}" | grep -q "^$container$"; then
            found_containers+=("$container")
            log "⚠️  Nalezen kontejner: $container"
        fi
    done
    
    if [ ${#found_containers[@]} -gt 0 ]; then
        confirm_action "Nalezeny kontejnery: ${found_containers[*]}. Chcete je odstranit?" || return
        
        log "Zastavování a odstraňování kontejnerů..."
        for container in "${found_containers[@]}"; do
            log "Odstraňování: $container"
            docker stop "$container" 2>/dev/null || true
            docker rm "$container" 2>/dev/null || true
        done
        
        log "Čištění Docker sítě a volumů..."
        docker network prune -f
        docker volume prune -f
    else
        log "✅ Žádné konfliktní Docker kontejnery nenalezeny"
    fi
}

# Kontrola a odstranění balíčků
cleanup_packages() {
    log "🔍 KONTROLA BALÍČKŮ"
    
    local packages=("homeassistant-supervised" "os-agent" "hassio-supervisor")
    local found_packages=()
    
    for pkg in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii  $pkg "; then
            found_packages+=("$pkg")
            log "⚠️  Nalezen balíček: $pkg"
        fi
    done
    
    if [ ${#found_packages[@]} -gt 0 ]; then
        confirm_action "Nalezeny balíčky: ${found_packages[*]}. Chcete je odstranit?" || return
        
        log "Odstraňování balíčků..."
        for pkg in "${found_packages[@]}"; do
            log "Odstraňování: $pkg"
            sudo dpkg --purge "$pkg" 2>/dev/null || true
        done
        sudo apt-get autoremove -y
        sudo apt-get autoclean -y
    else
        log "✅ Žádné konfliktní balíčky nenalezeny"
    fi
}

# Kontrola a odstranění služeb
cleanup_services() {
    log "🔍 KONTROLA SLUŽEB"
    
    local services=("homeassistant" "haos-agent" "hassio-supervisor" "hassio-apparmor")
    local found_services=()
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "$service.service"; then
            found_services+=("$service")
            log "⚠️  Nalezena služba: $service"
        fi
    done
    
    if [ ${#found_services[@]} -gt 0 ]; then
        confirm_action "Nalezeny služby: ${found_services[*]}. Chcete je odstranit?" || return
        
        log "Zastavování a zakazování služeb..."
        for service in "${found_services[@]}"; do
            log "Zpracovávám službu: $service"
            sudo systemctl stop "$service" 2>/dev/null || true
            sudo systemctl disable "$service" 2>/dev/null || true
            sudo systemctl reset-failed "$service" 2>/dev/null || true
        done
        
        log "Obnova systemd..."
        sudo systemctl daemon-reload
        sudo systemctl reset-failed
    else
        log "✅ Žádné konfliktní služby nenalezeny"
    fi
}

# Kontrola a odstranění konfiguračních souborů
cleanup_configs() {
    log "🔍 KONTROLA KONFIGURAČNÍCH SOUBORŮ"
    
    local config_paths=(
        "/home/$USER_NAME/homeassistant"
        "/home/$USER_NAME/.homeassistant"
        "/home/$USER_NAME/ha-config"
        "/opt/hassio"
        "/usr/share/hassio"
        "/etc/hassio"
    )
    
    local found_configs=()
    
    for path in "${config_paths[@]}"; do
        if [ -e "$path" ]; then
            found_configs+=("$path")
            log "⚠️  Nalezena konfigurace: $path"
        fi
    done
    
    if [ ${#found_configs[@]} -gt 0 ]; then
        confirm_action "Nalezeny konfigurační soubory. Chcete je zálohovat a odstranit?" || return
        
        log "Vytváření zálohy v: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        
        for path in "${found_configs[@]}"; do
            backup_files "$path"
            log "Odstraňování: $path"
            sudo rm -rf "$path" 2>/dev/null || true
        done
    else
        log "✅ Žádné konfliktní konfigurační soubory nenalezeny"
    fi
}

# Kontrola a oprava systémových souborů
cleanup_system_files() {
    log "🔍 KONTROLA SYSTÉMOVÝCH SOUBORŮ"
    
    # Kontrola /boot/config.txt
    if [ -f "/boot/config.txt" ] && grep -q "MHS35\|hdmi_cvt\|hdmi_group=2" /boot/config.txt; then
        log "⚠️  Nalezena konfigurace displeje v /boot/config.txt"
        confirm_action "Chcete odstranit konfiguraci displeje z /boot/config.txt?" && {
            sudo cp /boot/config.txt /boot/config.txt.backup.cleanup
            sudo sed -i '/# MHS35 Displej konfigurace/,/display_rotate=0/d' /boot/config.txt
            sudo sed -i '/MHS35\|hdmi_cvt\|hdmi_group=2/d' /boot/config.txt
            log "✅ Konfigurace displeje odstraněna"
        }
    fi
    
    # Kontrola Docker daemon.json
    if [ -f "/etc/docker/daemon.json" ]; then
        log "⚠️  Nalezen Docker daemon.json"
        backup_files "/etc/docker/daemon.json"
        confirm_action "Chcete obnovit výchozí Docker konfiguraci?" && {
            sudo rm -f /etc/docker/daemon.json
            sudo systemctl restart docker
            log "✅ Docker konfigurace obnovena"
        }
    fi
}

# Kontrola uživatelských skupin a oprávnění
cleanup_permissions() {
    log "🔍 KONTROLA OPRÁVNĚNÍ"
    
    local groups=("docker" "dialout" "tty")
    
    for group in "${groups[@]}"; do
        if groups "$USER_NAME" | grep -q "\b$group\b"; then
            log "✅ Uživatel $USER_NAME je v skupině $group"
        else
            log "⚠️  Uživatel $USER_NAME NENÍ v skupině $group"
            confirm_action "Chcete přidat uživatele $USER_NAME do skupiny $group?" && {
                sudo usermod -aG "$group" "$USER_NAME"
                log "✅ Uživatel přidán do skupiny $group"
            }
        fi
    done
}

# Kontrola portů a procesů
cleanup_ports_processes() {
    log "🔍 KONTROLA PORTŮ A PROCESŮ"
    
    local ports=("8123" "1883" "9000" "1880" "9001")
    local found_processes=()
    
    for port in "${ports[@]}"; do
        if lsof -i ":$port" >/dev/null 2>&1; then
            local process=$(lsof -i ":$port" | awk 'NR==2 {print $1, $2}')
            found_processes+=("Port $port: $process")
            log "⚠️  Nalezen proces na portu $port: $process"
        fi
    done
    
    if [ ${#found_processes[@]} -gt 0 ]; then
        confirm_action "Nalezeny procesy na portech. Chcete je zastavit?" || return
        
        for port in "${ports[@]}"; do
            local pids=$(lsof -ti ":$port")
            if [ -n "$pids" ]; then
                log "Zastavování procesů na portu $port: $pids"
                sudo kill -9 $pids 2>/dev/null || true
            fi
        done
        
        # Kontrola znovu
        sleep 2
        for port in "${ports[@]}"; do
            if lsof -i ":$port" >/dev/null 2>&1; then
                log "❌ Proces na portu $port stále běží, nutný manuální zásah"
            else
                log "✅ Port $port je volný"
            fi
        done
    else
        log "✅ Žádné konfliktní procesy na portech nenalezeny"
    fi
}

# Hlavní funkce pro kontrolu
main_check() {
    log "🔍 SPUŠTĚNÍ KONTROLY KOLIZÍ"
    
    echo "=========================================="
    echo "🧹 CLEANUP PREVIOUS INSTALLATIONS"
    echo "=========================================="
    echo "Tento skript zkontroluje a odstraní:"
    echo "• Docker kontejnery a sítě"
    echo "• Balíčky Home Assistant"
    echo "• Systémové služby"
    echo "• Konfigurační soubory"
    echo "• Procesy na portech"
    echo "=========================================="
    
    if [ "$1" != "--auto" ]; then
        confirm_action "Spustit kontrolu kolizí?" || exit 0
    fi
    
    # Vytvoření zálohového adresáře
    mkdir -p "$BACKUP_DIR"
    
    # Spuštění všech kontrol
    cleanup_docker
    cleanup_packages
    cleanup_services
    cleanup_configs
    cleanup_system_files
    cleanup_permissions
    cleanup_ports_processes
    
    log "✅ KONTROLA DOKONČENA"
    
    # Zobrazení souhrnu
    echo ""
    echo "=========================================="
    echo "📊 SOUHRN KONTROLY"
    echo "=========================================="
    echo "• Zálohy vytvořeny v: $BACKUP_DIR"
    echo "• Log soubor: $LOG_FILE"
    echo ""
    echo "📋 Doporučené další kroky:"
    echo "1. Odhlaste se a znovu přihlaste pro aplikování skupin"
    echo "2. Spusťte: ./check_configs.sh pro kontrolu konfigurace"
    echo "3. Spusťte: ./setup_master.sh pro čistou instalaci"
    echo "=========================================="
}

# Funkce pro obnovu ze zálohy
restore_backup() {
    local backup_path=$1
    
    if [ -z "$backup_path" ]; then
        echo "Použití: $0 restore <cesta_k_záloze>"
        echo "Dostupné zálohy:"
        find /home/"$USER_NAME" -name "ha_backup_*" -type d 2>/dev/null || echo "Žádné zálohy nenalezeny"
        exit 1
    fi
    
    if [ ! -d "$backup_path" ]; then
        log "❌ Záloha $backup_path neexistuje"
        exit 1
    fi
    
    confirm_action "Obnovit zálohu z $backup_path? Toto přepíše současná data." || exit 0
    
    log "Obnova zálohy: $backup_path"
    cp -r "$backup_path"/* ~/ 2>/dev/null || sudo cp -r "$backup_path"/* ~/
    
    log "✅ Obnova dokončena"
}

# Zobrazení nápovědy
show_help() {
    echo "Použití: $0 [příkaz]"
    echo ""
    echo "Příkazy:"
    echo "  check       Kontrola a odstranění kolizí (výchozí)"
    echo "  auto        Automatická kontrola bez potvrzení"
    echo "  restore     Obnova ze zálohy"
    echo "  help        Zobrazení této nápovědy"
    echo ""
    echo "Příklady:"
    echo "  ./cleanup_previous.sh check"
    echo "  ./cleanup_previous.sh auto"
    echo "  ./cleanup_previous.sh restore /home/user/ha_backup_20250101_120000"
    echo "  ./cleanup_previous.sh help"
}

# Hlavní logika
case "${1:-check}" in
    "check")
        main_check
        ;;
    "auto")
        main_check --auto
        ;;
    "restore")
        restore_backup "$2"
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        echo "Neplatný příkaz: $1"
        show_help
        exit 1
        ;;
esac
