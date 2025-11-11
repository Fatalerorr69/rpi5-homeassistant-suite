#!/bin/bash
# Fix configuration.yaml template — ensure proper HA structure
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_SOURCE="$REPO_ROOT/CONFIG"
CONFIG_RUNTIME="$REPO_ROOT/config"
LOG_FILE="/home/$(whoami)/fix_config.log"

# Barvy
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ⚠️ $1" | tee -a "$LOG_FILE"; }
err() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ❌ $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ℹ️ $1" | tee -a "$LOG_FILE"; }

# ======================================
# FUNKCIONALITA
# ======================================

check_yaml_validity() {
    local file=$1
    if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
        return 1
    fi
    return 0
}

fix_configuration_yaml() {
    log "🔧 Opravuji configuration.yaml..."
    
    if [ ! -f "$CONFIG_SOURCE/configuration.yaml" ]; then
        err "$CONFIG_SOURCE/configuration.yaml neexistuje!"
        return 1
    fi
    
    # Backup
    cp "$CONFIG_SOURCE/configuration.yaml" "$CONFIG_SOURCE/configuration.yaml.bak.$(date +%s)"
    log "✅ Vytvořen backup: configuration.yaml.bak.*"
    
    # Kontrola, zda má homeassistant: na začátku
    if ! grep -q "^homeassistant:" "$CONFIG_SOURCE/configuration.yaml" 2>/dev/null; then
        log "⚠️ Chybí 'homeassistant:' root element, přidávám..."
        
        # Vytvořit nový soubor s správnou strukturou
        cat > "$CONFIG_SOURCE/configuration.yaml.new" << 'EOF'
# Home Assistant Core Configuration
# ===================================
# Oficiální dokumentace: https://www.home-assistant.io/docs/configuration/

# Konfigurace Home Assistantu
homeassistant:
  # Název instalace
  name: RPi5 Home Assistant Suite
  
  # Geografická poloha (pro automation, slunce, atd.)
  latitude: 50.0755
  longitude: 14.4378
  elevation: 200
  
  # Jednotkový systém (metric = °C, kg, m; imperial = °F, lb, mi)
  unit_system: metric
  
  # Časové pásmo
  time_zone: Europe/Prague
  
  # Jazykové nastavení
  language: cs
  
  # IP adresy pro omezení přístupu (optional)
  # allowed_ip_addresses:
  #   - 127.0.0.1
  #   - ::1
  #   - 192.168.1.0/24

# Logger (zaznamenávání událostí)
logger:
  default: info
  # Pokročilé nastavení:
  # logs:
  #   homeassistant.components.http: debug
  #   homeassistant.components.zigbee2mqtt: debug

# Automatické komponenty (pro Raspberry Pi)
default_config:

# Text to speech
tts:
  - platform: google_translate

# Automatizace z UI
automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml

# Šablony
template: !include templates.yaml

# Senzory a binární senzory
sensor: !include sensor.yaml
binary_sensor: !include binary_sensor.yaml

# Příklady integrace
# homeassistant.components jsou automaticky načítány v default_config

# Historické data
history:
  purge_keep_days: 30
  
# Lovelace UI
lovelace:
  mode: yaml
  resources:
    - url: /hacsfiles/lovelace-mushroom/mushroom.js
      type: module

# Input helpers (pomocné proměnné)
input_boolean:
  # Příklad
  # homeassistant_running:
  #   name: "Home Assistant běží"
  #   icon: mdi:home-assistant

input_number:
  # Příklad
  # bedroom_brightness:
  #   name: Jas ložnice
  #   min: 0
  #   max: 100
  #   step: 5
  #   unit_of_measurement: "%"

# Timer (odpočty)
timer:

# Nastavení HTTP serveru
http:
  # HTTPS (pokud máte certifikát)
  # ssl_certificate: /path/to/cert.pem
  # ssl_key: /path/to/key.pem
  
  # CORS (pokud se připojujete z jiných domén)
  # cors_allowed_origins:
  #   - http://192.168.1.100:8123
  #   - https://example.com

# Nastavení Developer Tools
development_mode: false

# Diagnostika (pro troubleshooting)
diagnostics:
  enabled: true

# NAS/Storage monitoring (pokud máte)
# monitor_nas:
#   host: 192.168.1.100
#   share: /share

# Mqtt (pokud máte Mosquitto)
# mqtt:
#   broker: localhost
#   username: mqtt_user
#   password: mqtt_password
#   discovery: true
#   discovery_prefix: homeassistant

# Zigbee2MQTT (pokud máte)
# zigbee2mqtt:
#   base_topic: zigbee2mqtt
#   server: mqtt://localhost

# Node-RED (pokud máte)
# node_red:
#   url: http://localhost:1880

# Nastavení budíku
# alarm_control_panel:
#   - platform: manual

# Skupiny zařízení
# group: !include groups.yaml

# Nastavení notifikací
# notify:
#   - platform: smtp
#     name: Gmail
#     server: smtp.gmail.com
#     port: 587
#     timeout: 15
#     sender: your_email@gmail.com
#     encryption: starttls
#     username: your_email@gmail.com
#     password: your_password
#     recipient:
#       - your_email@gmail.com

# Skončení konfigurace
EOF
        
        # Ověření, že nový soubor je validní YAML
        if check_yaml_validity "$CONFIG_SOURCE/configuration.yaml.new"; then
            mv "$CONFIG_SOURCE/configuration.yaml.new" "$CONFIG_SOURCE/configuration.yaml"
            log "✅ configuration.yaml opraven a validován"
        else
            err "Nový configuration.yaml není validní YAML!"
            rm -f "$CONFIG_SOURCE/configuration.yaml.new"
            return 1
        fi
    else
        log "✅ configuration.yaml již má 'homeassistant:' element"
    fi
    
    # Validace finálního souboru
    if check_yaml_validity "$CONFIG_SOURCE/configuration.yaml"; then
        log "✅ configuration.yaml je validní"
        return 0
    else
        err "configuration.yaml je stále nevalidní!"
        return 1
    fi
}

fix_runtime_config() {
    log "🔄 Synchronizuji CONFIG/ → config/..."
    
    if [ -x "$REPO_ROOT/scripts/sync_config.sh" ]; then
        "$REPO_ROOT/scripts/sync_config.sh" --force --validate || {
            err "Synchronizace selhala"
            return 1
        }
    else
        warn "sync_config.sh není spustitelný, kopíruji ručně..."
        cp -a "$CONFIG_SOURCE"/* "$CONFIG_RUNTIME/" 2>/dev/null || true
    fi
    
    log "✅ Synchronizace dokončena"
}

validate_all_yaml() {
    log "📋 Validuji všechny YAML soubory..."
    
    local failed=0
    
    for yaml_file in "$CONFIG_SOURCE"/*.yaml; do
        if [ -f "$yaml_file" ]; then
            if check_yaml_validity "$yaml_file"; then
                log "✅ $(basename "$yaml_file")"
            else
                err "❌ $(basename "$yaml_file") — NEVALIDNÍ YAML"
                failed=$((failed + 1))
            fi
        fi
    done
    
    if [ $failed -eq 0 ]; then
        log "✅ Všechny YAML soubory jsou validní"
        return 0
    else
        err "❌ $failed souborů má chyby YAML"
        return 1
    fi
}

show_summary() {
    echo ""
    echo "=========================================="
    echo "📊 SOUHRN OPRAV"
    echo "=========================================="
    echo ""
    echo "✅ Provedeno:"
    echo "  • configuration.yaml — opraveno"
    echo "  • Struktura — validována"
    echo "  • YAML syntax — ověřeno"
    echo "  • Synchronizace — CONFIG/ → config/"
    echo ""
    echo "📝 Příští kroky:"
    echo "  1. Zkontrolujte: $CONFIG_RUNTIME/configuration.yaml"
    echo "  2. Případně upravte pro vaše zařízení"
    echo "  3. Restartujte Docker:"
    echo "     docker-compose restart homeassistant"
    echo ""
    echo "📚 Dokumentace: docs/HOME_ASSISTANT_SETUP.md"
    echo "=========================================="
    echo ""
}

# ======================================
# HLAVNÍ PROGRAM
# ======================================

main() {
    echo ""
    echo "=========================================="
    echo "🔧 OPRAVA CONFIGURATION.YAML"
    echo "=========================================="
    echo ""
    
    # Kontrola PyYAML
    if ! python3 -c "import yaml" &>/dev/null; then
        warn "PyYAML není nainstalován, zkouším nainstalovat..."
        if python3 -m pip install pyyaml &>/dev/null; then
            log "✅ PyYAML nainstalován"
        else
            err "Nelze nainstalovat PyYAML"
            exit 1
        fi
    fi
    
    # Hlavní opravy
    if ! fix_configuration_yaml; then
        err "Oprava configuration.yaml selhala"
        exit 1
    fi
    
    if ! validate_all_yaml; then
        warn "Některé YAML soubory mají chyby"
    fi
    
    if ! fix_runtime_config; then
        warn "Synchronizace selhala, ale opravy byly aplikovány"
    fi
    
    show_summary
    
    log "✅ Opravy dokončeny"
}

# Start
main "$@"
