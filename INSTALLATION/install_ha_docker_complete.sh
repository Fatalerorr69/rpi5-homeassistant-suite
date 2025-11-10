#!/bin/bash
# install_ha_docker_complete.sh
# Kompletní instalace Home Assistant přes Docker na RPi5 + dashboardy + konfigurace
# Autor: Starko, 2025

set -euo pipefail
IFS=$'\n\t'

LOG="/var/log/install_ha_docker_complete.log"
exec > >(tee -a "$LOG") 2>&1

# -------------------------- KONFIGURACE --------------------------
TIMEZONE="Europe/Prague"
HOSTNAME="rpi5-ha"
USERNAME="starko"

# Základní cesty
HA_CONFIG_DIR="/home/${USERNAME}/homeassistant"
NODERED_DATA_DIR="/home/${USERNAME}/nodered_data"
MOSQUITTO_DIR="/home/${USERNAME}/mosquitto"

# Porty
HA_PORT=8123
NODERED_PORT=1880
MOSQUITTO_PORT=1883
MOSQUITTO_WS_PORT=9001

# Barvy pro výstup
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funkce pro logování
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

err() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# -------------------------- KONTROLA ROOT A ZÁVISLOSTÍ --------------------------
check_dependencies() {
    log "Kontroluji závislosti..."
    if [ "$EUID" -ne 0 ]; then
        err "Skript musí být spuštěn jako root. Spusťte: sudo $0"
        exit 1
    fi

    if ! command -v docker &> /dev/null; then
        err "Docker není nainstalován. Nejprve nainstalujte Docker."
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! command -v docker compose &> /dev/null; then
        err "Docker Compose není nainstalován. Nainstalujte jej."
        exit 1
    fi
}

# -------------------------- PŘÍPRAVA ADRESÁŘŮ --------------------------
prepare_directories() {
    log "Připravuji adresáře pro konfiguraci..."

    # Hlavní adresáře
    mkdir -p "$HA_CONFIG_DIR"
    mkdir -p "$NODERED_DATA_DIR"
    mkdir -p "$MOSQUITTO_DIR"/{config,data,log}

    # Podadresáře Home Assistant
    mkdir -p "$HA_CONFIG_DIR"/{dashboards,scripts,www,custom_components}

    # Nastavení vlastníka
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/{homeassistant,nodered_data,mosquitto}
    chmod -R 755 "$HA_CONFIG_DIR"
}

# -------------------------- KONFIGURACE MOSQUITTO --------------------------
configure_mosquitto() {
    log "Konfiguruji Mosquitto MQTT broker..."

    cat > "$MOSQUITTO_DIR/config/mosquitto.conf" << EOF
listener 1883 0.0.0.0
allow_anonymous true

listener 9001 0.0.0.0
protocol websockets
EOF

    chown -R ${USERNAME}:${USERNAME} "$MOSQUITTO_DIR"
}

# -------------------------- KONFIGURACE HOME ASSISTANT --------------------------
configure_home_assistant() {
    log "Vytvářím konfiguraci Home Assistant..."

    # configuration.yaml
    cat > "$HA_CONFIG_DIR/configuration.yaml" << 'EOF'
homeassistant:
  name: Domov
  latitude: 50.0755
  longitude: 14.4378
  elevation: 200
  unit_system: metric
  time_zone: Europe/Prague

# Použít výchozí integrace
default_config:

# Lovelace v YAML režimu
lovelace:
  mode: yaml

# MQTT
mqtt:
  broker: 127.0.0.1
  port: 1883
  discovery: true
  discovery_prefix: homeassistant

# Energy framework (placeholder)
energy:

# Recorder
recorder:
  purge_keep_days: 7

# Logger
logger:
  default: info
  logs:
    custom_components.hacs: debug
    homeassistant.components.mqtt: debug

# System monitoring sensors
sensor: !include_dir_merge_list sensors/
# Automations
automation: !include automations.yaml
# Scripts
script: !include scripts.yaml
# Scenes
scene: !include scenes.yaml
EOF

    # ui-lovelace.yaml - hlavní dashboard
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
          - type: glance
            title: Rychlé ovládání
            entities:
              - switch.lights
              - switch.heating

  - title: Energie
    path: energy
    icon: mdi:lightning-bolt
    cards:
      - type: markdown
        content: |
          ## Energy Dashboard
          Po instalaci energetických senzorů (např. přes MQTT nebo Zigbee) upravte entity v energy dashboard.

  - title: Zařízení
    path: devices
    icon: mdi:devices
    cards:
      - type: entities
        title: Připojená zařízení
        entities:
          - device_tracker.my_phone

  - title: System
    path: system
    icon: mdi:server
    cards:
      - type: entities
        title: Systémové informace
        entities:
          - sensor.cpu_temperature
          - sensor.memory_use_percent
          - sensor.disk_use_percent
EOF

    # Vytvoření adresáře pro senzory a základní senzory
    mkdir -p "$HA_CONFIG_DIR/sensors"

    cat > "$HA_CONFIG_DIR/sensors/system_sensors.yaml" << 'EOF'
- platform: command_line
  name: cpu_temperature
  command: "cat /sys/class/thermal/thermal_zone0/temp | awk '{printf(\"%.1f\", \$1/1000)}'"
  unit_of_measurement: "°C"
  scan_interval: 30

- platform: command_line
  name: memory_free
  command: "free -m | awk '/Mem:/ {print \$4}'"
  unit_of_measurement: "MB"
  scan_interval: 60

- platform: command_line
  name: memory_use_percent
  command: "free | awk '/Mem:/ {printf(\"%.1f\", \$3/\$2 * 100.0)}'"
  unit_of_measurement: "%"
  scan_interval: 60

- platform: command_line
  name: disk_use_percent
  command: "df -h / | awk 'NR==2 {print \$5}' | tr -d '%'"
  unit_of_measurement: "%"
  scan_interval: 300
EOF

    # automations.yaml
    cat > "$HA_CONFIG_DIR/automations.yaml" << 'EOF'
- alias: Upozornění na vysokou teplotu CPU
  description: Varování při vysoké teplotě CPU
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

    # scripts.yaml
    cat > "$HA_CONFIG_DIR/scripts.yaml" << 'EOF'
reboot_rpi:
  alias: Restart Raspberry Pi
  sequence:
    - service: homeassistant.restart
  mode: single
EOF

    # scenes.yaml (prázdný)
    cat > "$HA_CONFIG_DIR/scenes.yaml" << 'EOF'
[]
EOF

    # Přehledový dashboard
    cat > "$HA_CONFIG_DIR/dashboards/overview.yaml" << 'EOF'
title: Přehled
cards:
  - type: entities
    title: Základní informace
    entities:
      - sensor.uptime
      - sensor.date
  - type: glance
    title: Stav zařízení
    entities:
      - light.living_room
EOF

    # Energy dashboard
    cat > "$HA_CONFIG_DIR/dashboards/energy.yaml" << 'EOF'
title: Energie
cards:
  - type: entities
    title: Energetické zdroje
    entities:
      - sensor.energy_today
      - sensor.energy_consumption
  - type: markdown
    content: |
      ## Nastavení energetického sledování
      1. Přidejte energetické senzory přes MQTT nebo jiné integrace
      2. Konfigurujte v `configuration.yaml` v sekci `energy`
EOF

    # System dashboard
    cat > "$HA_CONFIG_DIR/dashboards/system.yaml" << 'EOF'
title: Systém
cards:
  - type: gauge
    title: Využití CPU
    entity: sensor.cpu_temperature
    unit: °C
    min: 0
    max: 100
  - type: gauge
    title: Využití paměti
    entity: sensor.memory_use_percent
    unit: '%'
    min: 0
    max: 100
  - type: gauge
    title: Využití disku
    entity: sensor.disk_use_percent
    unit: '%'
    min: 0
    max: 100
EOF

    # HACS konfigurace (pokud bude nainstalováno)
    cat > "$HA_CONFIG_DIR/custom_components/.gitkeep" << 'EOF'
# Adresář pro custom components (HACS)
EOF

    log "Konfigurace Home Assistant vytvořena"
}

# -------------------------- DOCKER KOMPOZICE --------------------------
create_docker_compose() {
    log "Vytvářím docker-compose.yml..."

    cat > /home/${USERNAME}/docker-compose.yml << EOF
version: '3.8'

services:
  homeassistant:
    image: "ghcr.io/home-assistant/home-assistant:stable"
    container_name: homeassistant
    privileged: true
    restart: unless-stopped
    network_mode: host
    volumes:
      - ${HA_CONFIG_DIR}:/config
      - /etc/localtime:/etc/localtime:ro
      - /run/dbus:/run/dbus:ro
    environment:
      - TZ=${TIMEZONE}

  nodered:
    image: nodered/node-red
    container_name: nodered
    restart: unless-stopped
    ports:
      - "${NODERED_PORT}:1880"
    volumes:
      - ${NODERED_DATA_DIR}:/data
    environment:
      - TZ=${TIMEZONE}

  mosquitto:
    image: eclipse-mosquitto
    container_name: mosquitto
    restart: unless-stopped
    ports:
      - "${MOSQUITTO_PORT}:1883"
      - "${MOSQUITTO_WS_PORT}:9001"
    volumes:
      - ${MOSQUITTO_DIR}/config/mosquitto.conf:/mosquitto/config/mosquitto.conf
      - ${MOSQUITTO_DIR}/data:/mosquitto/data
      - ${MOSQUITTO_DIR}/log:/mosquitto/log
    environment:
      - TZ=${TIMEZONE}
EOF

    chown ${USERNAME}:${USERNAME} /home/${USERNAME}/docker-compose.yml
}

# -------------------------- SPUŠTĚNÍ SLUŽEB --------------------------
start_services() {
    log "Spouštím služby..."

    cd /home/${USERNAME}

    # Stažení nejnovějších image
    docker compose pull

    # Spuštění služeb
    docker compose up -d

    # Počkáme chvíli, než se služby rozběhnou
    sleep 10

    log "Služby byly spuštěny"
}

# -------------------------- KONTROLA STAVU --------------------------
check_status() {
    log "Kontroluji stav služeb..."

    echo ""
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    local ha_status=$(docker inspect -f '{{.State.Status}}' homeassistant 2>/dev/null || echo "none")
    local nr_status=$(docker inspect -f '{{.State.Status}}' nodered 2>/dev/null || echo "none")
    local mqtt_status=$(docker inspect -f '{{.State.Status}}' mosquitto 2>/dev/null || echo "none")

    echo ""
    log "Stav služeb:"
    echo "  - Home Assistant: $ha_status"
    echo "  - Node-RED: $nr_status"
    echo "  - Mosquitto: $mqtt_status"

    if [ "$ha_status" = "running" ]; then
        log "Home Assistant je spuštěn. První inicializace může trvat několik minut."
    fi
}

# -------------------------- INSTALACE HACS --------------------------
install_hacs() {
    log "Pokus o instalaci HACS..."

    # Počkáme, až bude Home Assistant částečně běžet
    sleep 30

    # Stáhneme HACS
    if [ -d "$HA_CONFIG_DIR/custom_components/hacs" ]; then
        log "HACS již je nainstalováno"
        return 0
    fi

    mkdir -p /tmp/hacs
    cd /tmp/hacs

    # Stáhnout nejnovější HACS
    if wget https://github.com/hacs/integration/releases/latest/download/hacs.zip; then
        mkdir -p "$HA_CONFIG_DIR/custom_components/hacs"
        unzip hacs.zip -d "$HA_CONFIG_DIR/custom_components/hacs"
        log "HACS bylo staženo a rozbaleno"
        rm -rf /tmp/hacs
    else
        warn "Nepodařilo se stáhnout HACS. Instalaci dokončete manuálně."
        return 1
    fi

    # Restartovat Home Assistant pro načtení HACS
    docker restart homeassistant
    log "Home Assistant restartován pro načtení HACS"
}

# -------------------------- ZOBRAZENÍ INFORMACÍ --------------------------
show_info() {
    local ip_address=$(hostname -I | awk '{print $1}')

    echo ""
    log "=== INSTALACE DOKONČENA ==="
    echo ""
    echo "Služby jsou nyní přístupné na:"
    echo "  - Home Assistant:  http://${ip_address}:${HA_PORT}"
    echo "  - Node-RED:        http://${ip_address}:${NODERED_PORT}"
    echo "  - Mosquitto MQTT:  ${ip_address}:${MOSQUITTO_PORT}"
    echo ""
    echo "Adresáře:"
    echo "  - Home Assistant:  ${HA_CONFIG_DIR}"
    echo "  - Node-RED:        ${NODERED_DATA_DIR}"
    echo "  - Mosquitto:       ${MOSQUITTO_DIR}"
    echo ""
    warn "DŮLEŽITÉ:"
    echo "  1. První spuštění Home Assistant může trvat 5-10 minut"
    echo "  2. Po prvním spuštění dokončete nastavení v webovém rozhraní"
    echo "  3. Pro instalaci HACS: v nastavení přidejte integraci 'HACS'"
    echo ""
    echo "Pro správu služeb:"
    echo "  cd /home/${USERNAME} && docker-compose [stop|start|restart|logs]"
    echo ""
    log "Podrobnosti v logu: ${LOG}"
}

# -------------------------- HLAVNÍ PROGRAM --------------------------

main() {
# === KONFIGUROVATELNÉ PROMĚNNÉ ===
REQUIRED_USER="starko"
REQUIRED_DISK_SPACE_GB=10
REQUIRED_RAM_GB=2
REQUIRED_OS="Debian"

# === FUNKCE PRO KONTROLY ===

check_root() {
    if [[ $EUID -eq 0 ]]; then
        err "Skript NESPOUŠTĚJTE přímo jako root (sudo). Spusťte jej nejprve jako uživatel '$REQUIRED_USER'."
        exit 1
    fi
    log "Kontrola práv: OK (jsem uživatel $(whoami))"
}

check_username() {
    local current_user=$(whoami)
    if [[ "$current_user" != "$REQUIRED_USER" ]]; then
        err "Skript musí být spuštěn pod uživatelem '$REQUIRED_USER', ne pod '$current_user'."
        warn "Pokud uživatel '$REQUIRED_USER' neexistuje, vytvořte jej příkazem:"
        echo "sudo adduser $REQUIRED_USER"
        echo "A přidejte jej do skupiny sudo:"
        echo "sudo usermod -aG sudo $REQUIRED_USER"
        exit 1
    fi
    log "Kontrola uživatelského jména: OK ($REQUIRED_USER)"
}

check_os() {
    if grep -qi "debian" /etc/os-release; then
        log "Kontrola OS: Detekován Debian/Ubuntu"
    else
        err "Skript je optimalizován pro Debian/Ubuntu. Detekovaný systém:"
        cat /etc/os-release
        exit 1
    fi
}

check_disk_space() {
    local available_kb=$(df / | awk 'NR==2 {print $4}')
    local required_kb=$((REQUIRED_DISK_SPACE_GB * 1024 * 1024))
    
    if [[ $available_kb -lt $required_kb ]]; then
        err "Nedostatek místa na disku. K dispozici je ${available_kb} KB, požadováno je ${required_kb} KB."
        exit 1
    fi
    log "Kontrola místa na disku: OK (k dispozici: ${available_kb} KB)"
}

check_ram() {
    local total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local required_ram_kb=$((REQUIRED_RAM_GB * 1024 * 1024))
    
    if [[ $total_ram_kb -lt $required_ram_kb ]]; then
        err "Nedostatek RAM. K dispozici je ${total_ram_kb} KB, požadováno je ${required_ram_kb} KB."
        exit 1
    fi
    log "Kontrola RAM: OK (k dispozici: ${total_ram_kb} KB)"
}

check_architecture() {
    local arch=$(uname -m)
    if [[ "$arch" != "aarch64" && "$arch" != "armv7l" ]]; then
        warn "Detekovaná architektura: $arch. Skript je optimalizován pro ARM (Raspberry Pi)."
    else
        log "Kontrola architektury: OK ($arch)"
    fi
}

check_internet() {
    if ! wget -q --spider http://github.com; then
        err "Chyba připojení k internetu. Zkontrolujte síťové připojení."
        exit 1
    fi
    log "Kontrola internetového připojení: OK"
}

check_docker() {
    if command -v docker >/dev/null 2>&1; then
        warn "Docker je již nainstalován. Pro čistou instalaci jej odstraňte:"
        echo "sudo apt remove --purge docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc"
        exit 1
    fi
}

# === HLAVNÍ FUNKCE PRO PŘÍPRAVU SYSTÉMU ===

setup_system() {
    log "Zahajuji přípravu systému pro uživatele $REQUIRED_USER"
    
    # Aktualizace seznamu balíčků
    sudo apt update || {
        err "Selhala aktualizace seznamu balíčků"
        exit 1
    }
    
    # Instalace základních balíčků
    local base_packages=(curl wget git jq sudo ufw)
    log "Instaluji základní balíčky: ${base_packages[*]}"
    sudo apt install -y "${base_packages[@]}" || {
        err "Selhala instalace základních balíčků"
        exit 1
    }
    
    # Nastavení firewallu (základní)
    log "Nastavím základní firewall (povolení SSH a port $HA_PORT)"
    sudo ufw allow ssh
    sudo ufw allow $HA_PORT
    sudo ufw --force enable
    
    # Vytvoření potřebných adresářů
    local directories=(
        "/home/$REQUIRED_USER/homeassistant"
        "/home/$REQUIRED_USER/scripts"
        "/home/$REQUIRED_USER/backups"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            sudo mkdir -p "$dir"
            sudo chown "$REQUIRED_USER:$REQUIRED_USER" "$dir"
            log "Vytvořen adresář: $dir"
        fi
    done
    
    log "Příprava systému dokončena"
}

# === SPUŠTĚNÍ KONTROL A PŘÍPRAVY ===
run_preinstall_checks() {
    log "Zahajuji pre-instalační kontroly"
    
    check_username
    check_root
    check_os
    check_disk_space
    check_ram
    check_architecture
    check_internet
    check_docker
    
    log "Všechny pre-instalační kontroly úspěšné!"
}

    log "Spouštím kompletní instalaci Home Assistant přes Docker"

    check_dependencies
    prepare_directories
    configure_mosquitto
    configure_home_assistant
    create_docker_compose
    start_services
    check_status

    # Počkáme a pak zkusíme nainstalovat HACS
    sleep 60
    install_hacs &

    show_info

    log "Instalace dokončena"
}

main "$@"
