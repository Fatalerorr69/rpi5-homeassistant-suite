#!/bin/bash

# ==========================================
# 🏠 RPi5 HOME ASSISTANT SUITE - INSTALACE
# ==========================================
# Autor: Fatalerorr69
# Verze: 2.0
# Opraveno: problémy s os-agent, systemd-resolved, YAML konfigurace
# ==========================================

set -e  # Ukončit při chybě

# Proměnné
LOG_FILE="/home/$(whoami)/ha_suite_install.log"
HA_CONFIG_DIR="/home/$(whoami)/homeassistant"
DOCKER_COMPOSE_DIR="/home/$(whoami)/rpi5-homeassistant-suite"

# Funkce pro logování
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Funkce pro kontrolu závislostí
check_dependencies() {
    log "Kontrola závislostí..."
    
    local deps=("curl" "wget" "git" "jq" "docker" "docker-compose")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log "Chybějící závislosti: ${missing[*]}"
        return 1
    fi
    
    log "✅ Všechny závislosti jsou nainstalovány"
    return 0
}

# Funkce pro kontrolu YAML souborů
check_yaml_files() {
    log "Kontrola YAML konfiguračních souborů..."
    
    local yaml_files=(
        "docker-compose.yml"
        "config/configuration.yaml"
        "config/zigbee2mqtt/configuration.yaml"
        "config/mosquitto/mosquitto.conf"
    )
    
    for file in "${yaml_files[@]}"; do
        if [ -f "$file" ]; then
            if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
                log "✅ $file - platný YAML"
            else
                log "❌ $file - neplatný YAML syntax"
                return 1
            fi
        else
            log "⚠️ $file - soubor neexistuje"
        fi
    done
    
    return 0
}

# Funkce pro kontrolu skriptů
check_scripts() {
    log "Kontrola skriptů..."
    
    local scripts=(
        "setup_master.sh"
        "install.sh"
        "mhs35_setup.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                log "✅ $script - spustitelný"
            else
                log "⚠️ $script - není spustitelný, opravuji..."
                chmod +x "$script"
            fi
        else
            log "❌ $script - chybí"
        fi
    done
}

# Funkce pro instalaci os-agent a systemd-resolved
install_ha_prerequisites() {
    log "Instalace předpokladů pro Home Assistant..."
    
    # Instalace systemd-resolved
    if ! dpkg -l | grep -q systemd-resolved; then
        log "Instalace systemd-resolved..."
        sudo apt-get update
        sudo apt-get install -y systemd-resolved
        sudo systemctl enable systemd-resolved
        sudo systemctl start systemd-resolved
    else
        log "✅ systemd-resolved je již nainstalován"
    fi
    
    # Instalace os-agent
    if ! dpkg -l | grep -q os-agent; then
        log "Instalace os-agent..."
        wget -O /tmp/os-agent_1.6.0_linux_aarch64.deb \
            https://github.com/home-assistant/os-agent/releases/download/1.6.0/os-agent_1.6.0_linux_aarch64.deb
        sudo dpkg -i /tmp/os-agent_1.6.0_linux_aarch64.deb
        sudo systemctl enable haos-agent
        sudo systemctl start haos-agent
    else
        log "✅ os-agent je již nainstalován"
    fi
}

# Funkce pro instalaci Home Assistant Supervised
install_ha_supervised() {
    log "🚀 INSTALACE HOME ASSISTANT SUPERVISED"
    
    # Kontroly před instalací
    if [ "$(whoami)" = "root" ]; then
        log "❌ Chyba: Skript nesmí být spuštěn jako root"
        exit 1
    fi
    
    # Kontrola sudo
    if ! sudo -n true 2>/dev/null; then
        log "🔐 Vyžadováno sudo heslo..."
    fi
    
    # Instalace předpokladů
    install_ha_prerequisites
    
    # Kontrola závislostí
    local packages=(
        "curl" "git" "jq" "apparmor" "dbus" "network-manager"
        "python3-pip" "software-properties-common" "libglib2.0-bin"
    )
    
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            log "Instalace balíčku: $pkg"
            sudo apt-get install -y "$pkg"
        fi
    done
    
    # Kontrola Dockeru
    if ! systemctl is-active --quiet docker; then
        log "Instalace Dockeru..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh
        sudo usermod -aG docker "$(whoami)"
        sudo systemctl enable docker
        sudo systemctl start docker
    fi
    
    # Stáhnout a nainstalovat Home Assistant Supervised
    log "Stahování Home Assistant Supervised..."
    wget -O /tmp/homeassistant-supervised.deb \
        https://github.com/home-assistant/supervised-installer/releases/latest/download/homeassistant-supervised.deb
    
    log "Instalace Home Assistant Supervised..."
    sudo dpkg -i /tmp/homeassistant-supervised.deb || true
    sudo apt-get install -f -y  # Oprava závislostí
    
    log "⏳ Čekám na inicializaci Home Assistant (může trvat 10-15 minut)..."
    
    # Čekání na spuštění služby
    local timeout=900
    local counter=0
    
    while [ $counter -lt $timeout ]; do
        if systemctl is-active --quiet homeassistant; then
            log "✅ Home Assistant úspěšně nainstalován a spuštěn"
            log "🌐 Přístup na: http://homeassistant.local:8123"
            log "🌐 Přístup na: http://$(hostname -I | awk '{print $1}'):8123"
            return 0
        fi
        sleep 30
        counter=$((counter + 30))
        log "Čekám... ($counter/$timeout sekund)"
    done
    
    log "❌ Timeout - Home Assistant se nespustil"
    log "Zkontrolujte logy: sudo journalctl -u homeassistant -f"
    return 1
}

# Funkce pro instalaci Docker komponent
install_docker_components() {
    log "Instalace Docker komponent..."
    
    cd "$DOCKER_COMPOSE_DIR"
    
    # Kontrola docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
        log "❌ Chybí docker-compose.yml"
        return 1
    fi
    
    # Spuštění služeb
    log "Spouštění služeb..."
    docker-compose up -d
    
    # Kontrola běžících kontejnerů
    log "Kontrola kontejnerů..."
    docker-compose ps
    
    log "✅ Docker komponenty nainstalovány"
}

# Funkce pro instalaci MHS35 displeje
install_mhs35_display() {
    log "Instalace MHS35 displeje..."
    
    if [ ! -f "mhs35_setup.sh" ]; then
        log "❌ Chybí mhs35_setup.sh"
        return 1
    fi
    
    chmod +x mhs35_setup.sh
    ./mhs35_setup.sh
    
    log "✅ MHS35 displej nainstalován"
}

# Funkce pro diagnostiku
run_diagnostics() {
    log "🩺 SPUŠTĚNÍ DIAGNOSTIKY"
    
    echo "=== SYSTÉM ==="
    uname -a
    echo
    
    echo "=== DISKOVÝ PROSTOR ==="
    df -h
    echo
    
    echo "=== RAM ==="
    free -h
    echo
    
    echo "=== DOCKER ==="
    docker --version
    docker-compose --version
    docker ps
    echo
    
    echo "=== SLUŽBY ==="
    systemctl is-active homeassistant && echo "Home Assistant: ✅" || echo "Home Assistant: ❌"
    systemctl is-active haos-agent && echo "HA OS Agent: ✅" || echo "HA OS Agent: ❌"
    systemctl is-active docker && echo "Docker: ✅" || echo "Docker: ❌"
    echo
    
    echo "=== SÍŤ ==="
    hostname -I
    echo
    
    echo "=== YAML SOUBORY ==="
    check_yaml_files
    echo
    
    echo "=== SKRIPTY ==="
    check_scripts
    echo
}

# Funkce pro opravu problémů
fix_issues() {
    log "🔧 OPRAVA PROBLÉMŮ"
    
    # Oprava oprávnění
    log "Oprava oprávnění skriptů..."
    chmod +x *.sh
    
    # Oprava Docker oprávnění
    log "Oprava Docker oprávnění..."
    sudo usermod -aG docker "$(whoami)"
    
    # Oprava USB zařízení
    log "Nastavení USB zařízení..."
    sudo usermod -aG dialout "$(whoami)"
    
    # Restart služeb
    log "Restart Docker služby..."
    sudo systemctl restart docker
    
    # Kontrola a oprava YAML souborů
    check_yaml_files
    
    log "✅ Základní opravy dokončeny"
}

# Funkce pro optimalizaci úložišť
optimize_storage() {
    log "🗂️  OPTIMALIZACE ÚLOŽIŠŤ"
    
    # Čištění Docker cache
    log "Čištění Docker cache..."
    docker system prune -f
    
    # Kontrola diskového prostoru
    log "Stav disku:"
    df -h /
    
    log "✅ Optimalizace dokončena"
}

# Hlavní menu
show_menu() {
    clear
    echo "=========================================="
    echo "🏠 RPi5 HOME ASSISTANT SUITE - INSTALACE"
    echo "=========================================="
    echo "1) Kompletní instalace (doporučeno)"
    echo "2) Pouze Home Assistant Supervised"
    echo "3) Pouze Docker komponenty"
    echo "4) Pouze MHS35 displej"
    echo "5) Diagnostika systému"
    echo "6) Kontrola YAML a skriptů"
    echo "7) Optimalizace úložišť"
    echo "8) Oprava problémů"
    echo "9) Ukončit"
    echo "=========================================="
}

# Hlavní funkce
main() {
    log "Spuštění RPi5 Home Assistant Suite"
    
    # Kontrola, zda je skript spuštěn z správného adresáře
    if [ ! -f "docker-compose.yml" ]; then
        log "❌ Skript musí být spuštěn z adresáře s docker-compose.yml"
        exit 1
    fi
    
    while true; do
        show_menu
        read -p "Vyberte možnost [1-9]: " choice
        
        case $choice in
            1)
                log "Zahájení kompletní instalace..."
                check_scripts
                check_yaml_files
                install_ha_supervised
                install_docker_components
                ;;
            2)
                log "Instalace pouze Home Assistant Supervised..."
                install_ha_supervised
                ;;
            3)
                log "Instalace pouze Docker komponent..."
                check_yaml_files
                install_docker_components
                ;;
            4)
                log "Instalace MHS35 displeje..."
                install_mhs35_display
                ;;
            5)
                run_diagnostics
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            6)
                check_scripts
                check_yaml_files
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            7)
                optimize_storage
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            8)
                fix_issues
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            9)
                log "Ukončování..."
                exit 0
                ;;
            *)
                echo "Neplatná volba. Zkuste to znovu."
                sleep 2
                ;;
        esac
    done
}

# Spuštění hlavní funkce
main "$@"
