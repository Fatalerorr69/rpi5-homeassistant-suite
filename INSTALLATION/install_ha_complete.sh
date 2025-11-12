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

# Proměnné
REQUIRED_DISK_SPACE_GB=10
LOG_FILE="/home/$(whoami)/install_ha_complete.log"

# Funkce pro kontrolu sudo
lock_sudo_access() {
    log "Kontrola sudo přístupu..." 
    if ! sudo -v; then 
        err "Chyba: Nemáte potřebná sudo oprávnění" 
        exit 1 
    fi 
    log "Kontrola sudo: OK" 
}

# Funkce pro instalaci závislostí pro Supervised
check_dependencies() {
    log "Kontrola a instalace závislostí pro Home Assistant Supervised..." 

    sudo apt update || { err "Selhala aktualizace balíčků"; exit 1; } 

    # Základní balíčky
    local required_packages=(
        curl wget git jq sudo ufw
        apt-transport-https ca-certificates
        lsb-release gnupg2 python3-pip
        apparmor jq udisks2 libglib2.0-bin
        network-manager dbus systemd-journal-remote
    )

    for package in "${required_packages[@]}"; do 
        if ! dpkg -l | grep -q "^ii  $package "; then 
            log "Instalace balíčku: $package" 
            sudo apt install -y "$package" || { err "Selhala instalace: $package"; exit 1; } 
        fi 
    done 

    # Speciální ošetření pro software-properties-common v Trixie
    if apt-cache show software-properties-common > /dev/null 2>&1; then
        if ! dpkg -l | grep -q "^ii  software-properties-common "; then 
            log "Instalace software-properties-common" 
            sudo apt install -y software-properties-common || warn "software-properties-common nelze nainstalovat"
        fi
    else
        warn "Balíček software-properties-common není dostupný v Trixie, přeskočeno"
    fi

    log "Závislosti nainstalovány" 
}

check_disk_space() {
    local available_kb=$(df / | awk 'NR==2 {print $4}') 
    local required_kb=$((REQUIRED_DISK_SPACE_GB * 1024 * 1024)) 

    if [[ $available_kb -lt $required_kb ]]; then 
        err "Nedostatek místa na disku. K dispozici: ${available_kb}KB, potřebováno: ${required_kb}KB"
        exit 1
    fi
    log "Kontrola diskového prostoru: OK"
}

check_user() {
    local current_user=$(whoami)
    if [[ "$current_user" == "root" ]]; then
        err "Skript musí být spuštěn pod běžným uživatelem, ne 'root'"
        exit 1
    fi
    log "Kontrola uživatele: OK ($current_user)"
}

check_ram() {
    local total_ram=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    if [[ $total_ram -lt 2000000 ]]; then
        err "Nedostatek RAM. Potřebováno: 2GB, k dispozici: ${total_ram}KB"
        exit 1
    fi
    log "Kontrola RAM: OK (${total_ram}KB k dispozici)"
}

check_internet() {
    if ! curl -Is https://www.google.com > /dev/null 2>&1; then
        err "Chyba připojení k internetu"
        exit 1
    fi
    log "Kontrola internetu: OK"
}

setup_firewall() {
    log "Nastavení firewallu..."
    
    # Povolení UFW
    sudo ufw --force enable
    
    # Základní pravidla
    sudo ufw allow 22/tcp comment 'SSH'
    sudo ufw allow 80/tcp comment 'HTTP'
    sudo ufw allow 443/tcp comment 'HTTPS'
    sudo ufw allow 8123/tcp comment 'Home Assistant'
    sudo ufw allow 1883/tcp comment 'MQTT'
    sudo ufw allow 1880/tcp comment 'Node-RED'
    sudo ufw allow 9000/tcp comment 'Portainer'
    
    log "Firewall nastaven"
}

install_docker() {
    log "Instalace Dockeru..."
    
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker $USER
        newgrp docker
    else
        log "Docker je již nainstalován"
    fi
    
    # Spuštění Docker služby
    sudo systemctl enable docker
    sudo systemctl start docker
}

install_hass_supervised() {
    log "Instalace Home Assistant Supervised..."
    
    # Stáhnout instalační balíček
    wget -O /tmp/homeassistant-supervised.deb \
        https://github.com/home-assistant/supervised-installer/releases/latest/download/homeassistant-supervised.deb
    
    # Instalace
    sudo dpkg -i /tmp/homeassistant-supervised.deb || sudo apt --fix-broken install -y
    
    log "Home Assistant Supervised nainstalován"
}

wait_for_hassio() {
    log "Čekám na inicializaci Home Assistant Supervised (může trvat 10-15 minut)..."
    
    local max_wait=900  # 15 minut
    local wait_time=0
    
    while [[ $wait_time -lt $max_wait ]]; do
        if docker ps | grep -q "hassio_supervisor"; then
            log "Home Assistant Supervisor je spuštěn"
            return 0
        fi
        sleep 30
        wait_time=$((wait_time + 30))
        log "Čekám... ($wait_time/$max_wait sekund)"
    done
    
    err "Timeout čekání na Home Assistant Supervised"
    return 1
}

main() {
    log "🚀 SPOUŠTÍM KOMPLETNÍ INSTALACI HOME ASSISTANT SUPERVISED NA RPi5"
    log "Log: $LOG_FILE"
    
    log "Zahajuji pre-instalační kontroly..."
    check_user
    lock_sudo_access
    check_dependencies
    check_disk_space
    check_ram
    check_internet
    
    log "✅ Všechny kontroly úspěšné!"
    
    log "Příprava systému..."
    setup_firewall
    install_docker
    install_hass_supervised
    
    log "Čekám na dokončení instalace..."
    wait_for_hassio
    
    log "🎉 INSTALACE HOME ASSISTANT SUPERVISED DOKONČENA"
    log "Home Assistant bude dostupný na: http://$(hostname -I | awk '{print $1}'):8123"
    log "První spuštění může trvat několik minut..."
}

main "$@"