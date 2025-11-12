#!/bin/bash

# ==========================================
# 🏠 RPi5 HOME ASSISTANT - ZÁKLADNÍ INSTALACE
# ==========================================
# Tento skript instaluje základní závislosti
# ==========================================

set -uo pipefail  # Bez -e, aby se script nezastavil na chybě

# Proměnné
LOG_FILE="/home/$(whoami)/install_dependencies.log"
USER_NAME=$(whoami)

# Funkce pro logování
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Funkce pro kontrolu kritických chyb
check_error() {
    if [ $? -ne 0 ]; then
        log "❌ Chyba: $1"
        return 1  # Vrátit chybu místo exit
    fi
    return 0
}

# Hlavní instalační funkce
install_dependencies() {
    log "🚀 ZAHÁJENÍ INSTALACE ZÁVISLOSTÍ"
    
    # Kontrola sudo
    if [ "$EUID" -ne 0 ]; then
        log "🔐 Vyžadováno sudo oprávnění..."
        sudo -v
    fi

    # Aktualizace systému
    log "Aktualizace systému..."
    sudo apt-get update
    sudo apt-get upgrade -y

    # Instalace základních balíčků
    log "Instalace základních balíčků..."
    
    # Instalace balíčků - se zpracováním chyb (některé nemusí být dostupné)
    PACKAGES=(
        curl wget git jq
        python3 python3-pip python3-venv python3-dev
        libffi-dev libssl-dev libjpeg-dev zlib1g-dev
        autoconf build-essential
        libopenjp2-7 libopenjp2-7-dev
        libturbojpeg0 libturbojpeg0-dev
        tzdata lsb-release apt-transport-https
        ca-certificates gnupg2
        software-properties-common
        apparmor apparmor-utils
        dbus network-manager systemd-resolved
    )
    
    # Instalace s fallback pro chybějící balíčky
    for package in "${PACKAGES[@]}"; do
        if sudo apt-get install -y "$package" 2>/dev/null; then
            log "✅ Nainstalován: $package"
        else
            log "⚠️  Balík nedostupný: $package (přeskakuji)"
        fi
    done
    
    # Kontrola povinných balíčků
    if ! command -v curl &>/dev/null || ! command -v python3 &>/dev/null; then
        log "❌ Kritické balíčky chybí (curl, python3)"
        exit 1
    fi

    # Ensure PyYAML is available for YAML validation used elsewhere
    if ! python3 -c "import yaml" &>/dev/null; then
        log "PyYAML chybí, zkusím nainstalovat python3-yaml (apt)"
        if sudo apt-get install -y python3-yaml; then
            log "Nainstalováno python3-yaml přes apt"
        else
            log "apt selhal, zkouším pip3 install pyyaml"
            sudo pip3 install pyyaml || log "⚠️ Instalace PyYAML přes pip selhala"
        fi
    else
        log "✅ PyYAML je již nainstalován"
    fi

    # Instalace Dockeru
    log "Instalace Dockeru..."
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        if sudo sh /tmp/get-docker.sh; then
            log "✅ Docker nainstalován"
        else
            log "⚠️  Instalace Dockeru selhala (přeskakuji - nemusí být k dispozici v kontejneru)"
        fi
    else
        log "✅ Docker je již nainstalován"
    fi

    # Přidání uživatele do Docker skupiny
    log "Přidání uživatele $USER_NAME do Docker skupiny..."
    sudo usermod -aG docker "$USER_NAME" 2>/dev/null || log "⚠️  Přidání do docker skupiny selhalo"

    # Instalace Docker Compose
    log "Instalace Docker Compose..."
    if ! command -v docker-compose &> /dev/null; then
        if sudo apt-get install -y docker-compose-plugin; then
            log "✅ Docker Compose nainstalován"
        else
            log "⚠️  Instalace Docker Compose selhala (přeskakuji - nemusí být k dispozici)"
        fi
    else
        log "✅ Docker Compose je již nainstalován"
    fi

    # Instalace os-agent (volitelná)
    log "Instalace os-agent..."
    if ! dpkg -l 2>/dev/null | grep -q os-agent; then
        if wget -O /tmp/os-agent_1.6.0_linux_aarch64.deb \
            https://github.com/home-assistant/os-agent/releases/download/1.6.0/os-agent_1.6.0_linux_aarch64.deb 2>/dev/null; then
            if sudo dpkg -i /tmp/os-agent_1.6.0_linux_aarch64.deb 2>/dev/null; then
                sudo systemctl enable haos-agent 2>/dev/null || true
                sudo systemctl start haos-agent 2>/dev/null || true
                log "✅ os-agent nainstalován"
            else
                log "⚠️  Instalace os-agent balíčku selhala"
            fi
        else
            log "⚠️  Stažení os-agent selhalo"
        fi
    else
        log "✅ os-agent je již nainstalován"
    fi

    # Nastavení služeb
    log "Nastavení systémových služeb..."
    sudo systemctl enable docker 2>/dev/null || true
    sudo systemctl start docker 2>/dev/null || true
    sudo systemctl enable systemd-resolved 2>/dev/null || true
    sudo systemctl start systemd-resolved 2>/dev/null || true

    # Nastavení časového pásma
    log "Nastavení časového pásma na Europe/Prague..."
    sudo timedatectl set-timezone Europe/Prague

    # Nastavení USB oprávnění
    log "Nastavení oprávnění pro USB zařízení..."
    sudo usermod -aG dialout "$USER_NAME"
    sudo usermod -aG tty "$USER_NAME"

    # Vytvoření základní adresářové struktury
    log "Vytváření adresářové struktury..."
    mkdir -p ~/homeassistant
    mkdir -p ~/rpi5-homeassistant-suite/config/{mosquitto,zigbee2mqtt,node-red,portainer}

    log "✅ INSTALACE ZÁVISLOSTÍ DOKONČENA"
    log "📋 Pro aplikování změn se odhlaste a znovu přihlaste"
    log "🔧 Poté spusťte: ./setup_master.sh"
}

# Zobrazení nápovědy
show_help() {
    echo "Použití: $0 [příkaz]"
    echo ""
    echo "Příkazy:"
    echo "  install     Instalace závislostí (výchozí)"
    echo "  help        Zobrazení této nápovědy"
    echo ""
    echo "Příklady:"
    echo "  ./install.sh install"
    echo "  ./install.sh help"
}

# Hlavní logika
case "${1:-install}" in
    "install")
        install_dependencies
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
