#!/bin/bash
# install_ha_rpi5_complete.sh
# KOMPLETNÍ INSTALACE HOME ASSISTANT na Raspberry Pi 5
# Autor: Starko, 2025

set -euo pipefail
IFS=$'\n\t'

# -------------------------- KONFIGURACE --------------------------
LOG_FILE="/home/starko/install_ha_complete.log"
exec > >(tee -a "$LOG_FILE") 2>&1

TIMEZONE="Europe/Prague"
HOSTNAME="rpi5-ha"
REQUIRED_USER="starko"
REQUIRED_DISK_SPACE_GB=10
REQUIRED_RAM_GB=2

# Síťové porty
HA_PORT=8123
NODERED_PORT=1880
MOSQUITTO_PORT=1883
MOSQUITTO_WS_PORT=9001

# Cesty
HA_CONFIG_DIR="/home/${REQUIRED_USER}/homeassistant"
NODERED_DATA_DIR="/home/${REQUIRED_USER}/nodered_data"
MOSQUITTO_DIR="/home/${REQUIRED_USER}/mosquitto"
DOCKER_COMPOSE_DIR="/home/${REQUIRED_USER}/docker-compose"
BACKUP_DIR="/home/${REQUIRED_USER}/backups"

# Barvy pro výstup
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# -------------------------- FUNKCE --------------------------
log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
info() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
err() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }

# -------------------------- KONTROLY --------------------------
check_root() {
    if [[ $EUID -eq 0 ]]; then
        err "Skript NESPOUŠTĚJTE jako root! Spusťte jako uživatel '$REQUIRED_USER'"
        err "Použijte: ./$(basename "$0")"
        exit 1
    fi
}

check_username() {
    local current_user=$(whoami)
    if [[ "$current_user" != "$REQUIRED_USER" ]]; then
        err "Skript musí být spuštěn pod uživatelem '$REQUIRED_USER', ne '$current_user'"
        exit 1
    fi
    log "Kontrola uživatele: OK ($REQUIRED_USER)"
}

check_sudo_access() {
    log "Kontrola sudo přístupu..."
    if ! sudo -v; then
        err "Chyba: Nemáte potřebná sudo oprávnění"
        exit 1
    fi
    log "Kontrola sudo: OK"
}

check_dependencies() {
    log "Kontrola a instalace závislostí..."
    
    sudo apt update || { err "Selhala aktualizace balíčků"; exit 1; }
    
    local required_packages=(
        curl wget git jq sudo ufw 
        apt-transport-https ca-certificates 
        software-properties-common
        lsb-release gnupg2 python3-pip
    )
    
    for package in "${required_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            log "Instalace balíčku: $package"
            sudo apt install -y "$package" || { err "Selhala instalace: $package"; exit 1; }
        fi
    done
    log "✅ Závislosti nainstalovány"
}

check_disk_space() {
    local available_kb=$(df / | awk 'NR==2 {print $4}')
    local required_kb=$((REQUIRED_DISK_SPACE_GB * 1024 * 1024))
    
    if [[ $available_kb -lt $required_kb ]]; then
        err "Nedostatek místa na disku. K dispozici: ${available_kb}KB, potřebováno: ${required_kb}KB"
        exit 1
    fi
    log "Kontrola disku: OK (${available_kb}KB k dispozici)"
}

check_ram() {
    local total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local required_ram_kb=$((REQUIRED_RAM_GB * 1024 * 1024))
    
    if [[ $total_ram_kb -lt $required_ram_kb ]]; then
        err "Nedostatek RAM. K dispozici: ${total_ram_kb}KB, potřebováno: ${required_ram_kb}KB"
        exit 1
    fi
    log "Kontrola RAM: OK (${total_ram_kb}KB k dispozici)"
}

check_internet() {
    if ! wget -q --spider http://github.com; then
        err "Chyba připojení k internetu"
        exit 1
    fi
    log "Kontrola internetu: OK"
}

run_preinstall_checks() {
    log "Zahajuji pre-instalační kontroly..."
    check_username
    check_root
    check_sudo_access
    check_dependencies
    check_disk_space
    check_ram
    check_internet
    log "✅ Všechny kontroly úspěšné!"
}

# -------------------------- PŘÍPRAVA SYSTÉMU --------------------------
setup_system() {
    log "Příprava systému..."
    
    # Firewall
    log "Nastavení firewallu..."
    sudo ufw allow ssh
    sudo ufw allow $HA_PORT
    sudo ufw allow $NODERED_PORT
    sudo ufw allow $MOSQUITTO_PORT
    echo "y" | sudo ufw enable
    
    # Časové pásmo a hostname
    sudo timedatectl set-timezone "$TIMEZONE"
    sudo hostnamectl set-hostname "$HOSTNAME"
    
    # Vytvoření adresářů
    local directories=(
        "$HA_CONFIG_DIR" "$NODERED_DATA_DIR" "$MOSQUITTO_DIR"
        "$DOCKER_COMPOSE_DIR" "$BACKUP_DIR" "/home/$REQUIRED_USER/scripts"
    )
    
    for dir in "${directories[@]}"; do
        sudo mkdir -p "$dir"
        sudo chown "$REQUIRED_USER:$REQUIRED_USER" "$dir"
    done
    
    # Podadresáře
    mkdir -p "$HA_CONFIG_DIR"/{dashboards,scripts,www,custom_components,sensors}
    mkdir -p "$MOSQUITTO_DIR"/{config,data,log}
    
    log "✅ Příprava systému dokončena"
}

# -------------------------- INSTALACE DOCKER --------------------------
install_docker() {
    log "Instalace Dockeru..."
    
    if command -v docker &> /dev/null; then
        log "Docker je již nainstalován"
        return
    fi

    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    sudo usermod -aG docker "$REQUIRED_USER"
    rm /tmp/get-docker.sh
    
    sudo systemctl enable docker
    sudo systemctl start docker
    sleep 10
    
    log "✅ Docker nainstalován a spuštěn"
}

install_docker_compose() {
    log "Instalace Docker Compose..."
    
    if docker compose version &>/dev/null; then
        log "✅ Docker Compose (plugin) je již nainstalován"
        return
    fi
    
    log "Instalace Docker Compose plugin..."
    sudo apt update
    sudo apt install -y docker-compose-plugin
    
    if ! docker compose version &>/dev/null; then
        log "Instalace Docker Compose přes pip..."
        sudo pip3 install docker-compose
        sudo ln -s $(which docker-compose) /usr/local/bin/docker-compose 2>/dev/null || true
    fi
    
    if docker compose version &>/dev/null; then
        log "✅ Docker Compose plugin nainstalován"
    elif command -v docker-compose &>/dev/null; then
        log "✅ Docker Compose (standalone) nainstalován"
    else
        err "❌ Nepodařilo se nainstalovat Docker Compose"
        exit 1
    fi
}

# -------------------------- KONFIGURACE HOME ASSISTANT --------------------------
configure_home_assistant() {
    log "Konfigurace Home Assistant..."

    # configuration.yaml
    cat > "$HA_CONFIG_DIR/configuration.yaml" << 'EOF'
homeassistant:
  name: Domov
  latitude: 50.0755
  longitude: 14.4378
  elevation: 200
  unit_system: metric
  time_zone: Europe/Prague

default_config:

lovelace:
  mode: yaml

mqtt:
  broker: 127.0.0.1
  port: 1883
  discovery: true
  discovery_prefix: homeassistant

energy:

recorder:
  purge_keep_days: 7

logger:
  default: info

sensor: !include_dir_merge_list sensors/
automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml
EOF

    # ui-lovelace.yaml
    cat > "$HA_CONFIG_DIR/ui-lovelace.yaml" << 'EOF'
title: Domov - Přehled
views:
  - title: Přehled
    path: default_view
    badges:
      - entity: sun.sun
    cards:
      - type: vertical-stack
        cards:
          - type: entities
            title: Stav systému
            entities:
              - entity: sensor.cpu_temperature
                name: Teplota CPU
              - entity: sensor.memory_free
                name: Volná paměť
              - entity: sensor.disk_use_percent
                name: Využití disku
EOF

    # Senzory
    cat > "$HA_CONFIG_DIR/sensors/system_sensors.yaml" << 'EOF'
- platform: command_line
  name: cpu_temperature
  command: "cat /sys/class/thermal/thermal_zone0/temp | awk '{printf \"%.1f\", \$1/1000}'"
  unit_of_measurement: "°C"
  scan_interval: 30

- platform: command_line
  name: memory_free
  command: "free -m | awk '/Mem:/ {print \$4}'"
  unit_of_measurement: "MB"
  scan_interval: 60

- platform: command_line
  name: memory_use_percent
  command: "free | awk '/Mem:/ {printf \"%.1f\", \$3/\$2 * 100.0}'"
  unit_of_measurement: "%"
  scan_interval: 60

- platform: command_line
  name: disk_use_percent
  command: "df -h / | awk 'NR==2 {print \$5}' | tr -d '%'"
  unit_of_measurement: "%"
  scan_interval: 300
EOF

    # Automatizace
    cat > "$HA_CONFIG_DIR/automations.yaml" << 'EOF'
- alias: Upozornění na vysokou teplotu CPU
  trigger:
    - platform: numeric_state
      entity_id: sensor.cpu_temperature
      above: 70
  action:
    - service: persistent_notification.create
      data:
        title: Varování - vysoká teplota CPU
        message: "Teplota CPU dosáhla {{ states('sensor.cpu_temperature') }}°C"
  mode: single
EOF

    # Skripty
    cat > "$HA_CONFIG_DIR/scripts.yaml" << 'EOF'
reboot_rpi:
  alias: Restart Raspberry Pi
  sequence:
    - service: homeassistant.restart
  mode: single
EOF

    # Scény
    cat > "$HA_CONFIG_DIR/scenes.yaml" << 'EOF'
[]
EOF

    sudo chown -R "$REQUIRED_USER":"$REQUIRED_USER" "$HA_CONFIG_DIR"
    log "✅ Konfigurace Home Assistant vytvořena"
}

# -------------------------- DOCKER COMPOSE --------------------------
create_docker_compose() {
    log "Vytváření docker-compose.yml..."

    cat > "$DOCKER_COMPOSE_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  homeassistant:
    image: "ghcr.io/home-assistant/home-assistant:stable"
    container_name: homeassistant
    privileged: true
    restart: unless-stopped
    network_mode: host
    volumes:
      - $HA_CONFIG_DIR:/config
      - /etc/localtime:/etc/localtime:ro
      - /run/dbus:/run/dbus:ro
    environment:
      - TZ=$TIMEZONE

  nodered:
    image: nodered/node-red
    container_name: nodered
    restart: unless-stopped
    ports:
      - "$NODERED_PORT:1880"
    volumes:
      - $NODERED_DATA_DIR:/data
    environment:
      - TZ=$TIMEZONE

  mosquitto:
    image: eclipse-mosquitto
    container_name: mosquitto
    restart: unless-stopped
    ports:
      - "$MOSQUITTO_PORT:1883"
      - "$MOSQUITTO_WS_PORT:9001"
    volumes:
      - $MOSQUITTO_DIR/config:/mosquitto/config
      - $MOSQUITTO_DIR/data:/mosquitto/data
      - $MOSQUITTO_DIR/log:/mosquitto/log
EOF

    # Konfigurace Mosquitto
    cat > "$MOSQUITTO_DIR/config/mosquitto.conf" << 'EOF'
listener 1883 0.0.0.0
allow_anonymous true

listener 9001 0.0.0.0
protocol websockets
EOF

    sudo chown -R "$REQUIRED_USER":"$REQUIRED_USER" "$MOSQUITTO_DIR"
    log "✅ Docker Compose soubor vytvořen"
}

# -------------------------- SPUŠTĚNÍ SLUŽEB --------------------------
start_services() {
    log "Spouštění služeb..."
    cd "$DOCKER_COMPOSE_DIR"
    
    # Detekce compose příkazu
    if docker compose version &>/dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &>/dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        err "❌ Není dostupný žádný docker compose příkaz"
        exit 1
    fi
    
    log "Stahování Docker images..."
    $COMPOSE_CMD pull || warn "Některé images se nepodařilo stáhnout, pokračuji..."
    
    log "Spouštění kontejnerů..."
    $COMPOSE_CMD up -d
    sleep 10
    
    log "✅ Služby spuštěny"
}

# -------------------------- INSTALACE HACS --------------------------
install_hacs() {
    log "Instalace HACS..."
    sleep 30
    
    if [ -d "$HA_CONFIG_DIR/custom_components/hacs" ]; then
        log "HACS je již nainstalováno"
        return 0
    fi
    
    if wget -q https://github.com/hacs/integration/releases/latest/download/hacs.zip -O /tmp/hacs.zip; then
        mkdir -p "$HA_CONFIG_DIR/custom_components/hacs"
        unzip -q /tmp/hacs.zip -d "$HA_CONFIG_DIR/custom_components/hacs"
        rm /tmp/hacs.zip
        log "✅ HACS nainstalováno"
        return 0
    else
        warn "❌ Nepodařilo se stáhnout HACS"
        return 1
    fi
}

# -------------------------- MONITOROVÁNÍ --------------------------
setup_monitoring() {
    log "Nastavení monitorování..."

    # Health check skript
    cat > "/home/$REQUIRED_USER/health_check.sh" << 'EOF'
#!/bin/bash
echo "=== Health Check - $(date) ==="
echo "Kontejnery: $(docker ps -q | wc -l)/$(docker ps -a -q | wc -l) běžících"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"
EOF

    # Dashboard skript
    cat > "/home/$REQUIRED_USER/system_dashboard.sh" << 'EOF'
#!/bin/bash
echo "=== RPi5 HOME ASSISTANT ==="
echo "Čas: $(date)"
echo "Uptime: $(uptime -p)"

if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    echo "Teplota CPU: $((temp/1000))°C"
fi

echo "" && echo "--- KONTEJNERY ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
EOF

    chmod +x "/home/$REQUIRED_USER/health_check.sh" "/home/$REQUIRED_USER/system_dashboard.sh"
    log "✅ Monitorování nastaveno"
}

# -------------------------- KONTROLA STAVU --------------------------
check_status() {
    log "Kontrola stavu služeb..."
    sleep 20

    local ip=$(hostname -I | awk '{print $1}')
    
    echo ""
    log "🎉 INSTALACE DOKONČENA"
    echo ""
    echo "🌐 SLUŽBY:"
    echo "  Home Assistant:  http://${ip}:${HA_PORT}"
    echo "  Node-RED:        http://${ip}:${NODERED_PORT}" 
    echo "  Mosquitto MQTT:  ${ip}:${MOSQUITTO_PORT}"
    echo ""
    echo "📁 ADRESÁŘE:"
    echo "  Home Assistant:  ${HA_CONFIG_DIR}"
    echo "  Node-RED:        ${NODERED_DATA_DIR}"
    echo "  Docker Compose:  ${DOCKER_COMPOSE_DIR}"
    echo ""
    echo "🛠️  PŘÍKAZY:"
    echo "  ./system_dashboard.sh                    - Stav systému"
    echo "  cd $DOCKER_COMPOSE_DIR && docker compose logs    - Logy služeb"
    echo ""
    warn "⚠️  První spuštění Home Assistant může trvat 5-10 minut"
}

# -------------------------- HLAVNÍ PROGRAM --------------------------
main() {
    log "🚀 SPOUŠTÍM KOMPLETNÍ INSTALACI HOME ASSISTANT NA RPi5"
    log "Log: $LOG_FILE"
    
    run_preinstall_checks
    setup_system
    install_docker
    install_docker_compose
    configure_home_assistant
    create_docker_compose
    start_services
    install_hacs &
    setup_monitoring
    check_status
    
    log "✅ INSTALACE DOKONČENA"
    echo ""
    info "Pro zobrazení stavu spusťte: ./system_dashboard.sh"
}

main "$@"
