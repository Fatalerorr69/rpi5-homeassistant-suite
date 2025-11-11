#!/bin/bash

# ==========================================
# 🖥️  INSTALACE MHS35 DISPLEJE PRO RPi5
# ==========================================
# Skript pro konfiguraci MHS35 dotykového displeje
# ==========================================

set -e

# Proměnné
LOG_FILE="/home/$(whoami)/mhs35_install.log"
CONFIG_DIR="/home/$(whoami)/rpi5-homeassistant-suite/config"

# Funkce pro logování
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Funkce pro kontrolu chyb
check_error() {
    if [ $? -ne 0 ]; then
        log "❌ Chyba: $1"
        exit 1
    fi
}

# Kontrola oprávnění
check_privileges() {
    if [ "$EUID" -ne 0 ]; then
        log "🔐 Vyžadováno sudo oprávnění..."
        sudo -v
    fi
}

# Instalace závislostí pro displej
install_display_dependencies() {
    log "Instalace závislostí pro MHS35 displej..."
    
    sudo apt-get update
    sudo apt-get install -y \
        raspberrypi-kernel-headers \
        dkms \
        git \
        build-essential \
        evtest \
        xinput \
        libinput-tools

    log "✅ Závislosti nainstalovány"
}

# Stažení a instalace ovladačů
install_display_drivers() {
    log "Instalace ovladačů pro MHS35 displej..."
    
    # Dočasný adresář pro build
    local temp_dir="/tmp/mhs35_install"
    mkdir -p "$temp_dir"
    cd "$temp_dir"

    # Stažení zdrojových kódů (příklad - upravte podle skutečných ovladačů)
    if [ ! -d "LCD-show" ]; then
        git clone https://github.com/goodtft/LCD-show.git
        check_error "Stažení ovladačů selhalo"
    fi

    cd LCD-show

    # Spuštění instalačního skriptu pro MHS35
    if [ -f "MHS35-show" ]; then
        log "Spouštění instalačního skriptu MHS35..."
        chmod +x MHS35-show
        sudo ./MHS35-show
    else
        log "⚠️  Skript MHS35-show nebyl nalezen, používáme obecný instalátor"
        chmod +x LCD35-show
        sudo ./LCD35-show
    fi

    log "✅ Ovladače nainstalovány"
}

# Konfigurace rozlišení a dotyku
configure_display() {
    log "Konfigurace displeje..."
    
    # Záloha původní konfigurace
    sudo cp /boot/config.txt /boot/config.txt.backup.$(date +%Y%m%d_%H%M%S)

    # Přidání konfigurace pro MHS35 do config.txt
    if ! grep -q "MHS35" /boot/config.txt; then
        log "Přidávání konfigurace MHS35 do /boot/config.txt..."
        
        cat << EOF | sudo tee -a /boot/config.txt

# MHS35 Displej konfigurace
max_usb_current=1
hdmi_group=2
hdmi_mode=87
hdmi_cvt 480 320 60 6 0 0 0
hdmi_drive=1
display_rotate=0
EOF

    else
        log "✅ Konfigurace MHS35 již existuje"
    fi

    # Kalibrace dotyku (pokud je k dispozici)
    if command -v xinput &> /dev/null; then
        log "Kalibrace dotykového displeje..."
        # Toto může vyžadovat manuální kalibraci
        xinput_calibrator --output-type xinput | tee /etc/pointercal.xinput
    fi
}

# Konfigurace pro Home Assistant
configure_homeassistant() {
    log "Konfigurace Home Assistant pro displej..."
    
    local ha_config="$CONFIG_DIR/configuration.yaml"
    
    if [ -f "$ha_config" ]; then
        # Přidání konfigurace pro displej
        if ! grep -q "panel_iframe" "$ha_config"; then
            cat << EOF >> "$ha_config"

# Konfigurace pro MHS35 displej
panel_iframe:
  display:
    title: 'Ovládání'
    icon: mdi:monitor-dashboard
    url: 'http://localhost:8123/lovelace/default_view'

# Automatické spuštění dashboardu na displeji
default_config:
frontend:
  themes: !include_dir_merge_named themes
EOF
        fi

        # Vytvoření základního Lovelace dashboardu
        local lovelace_dir="$CONFIG_DIR/lovelace"
        mkdir -p "$lovelace_dir"
        
        cat << EOF > "$lovelace_dir/default_view.yaml"
title: Domov
views:
  - title: Přehled
    icon: mdi:home
    cards:
      - type: glance
        entities:
          - sun.sun
      - type: entities
        title: Světla
        entities:
          - entity: light.obývák
          - entity: light.kuchyň
      - type: entities  
        title: Teplota
        entities:
          - entity: sensor.obývák_teplota
          - entity: sensor.venkovni_teplota
EOF

    else
        log "⚠️  Konfigurační soubor Home Assistant nebyl nalezen"
    fi
}

# Testování displeje
test_display() {
    log "Testování displeje..."
    
    # Kontrola HDMI výstupu
    if tvservice -n | grep -q "MHS35"; then
        log "✅ Displej MHS35 byl detekován"
    else
        log "⚠️  Displej MHS35 nebyl detekován, kontrola připojení"
    fi

    # Test dotyku
    if command -v evtest &> /dev/null; then
        log "Test dotykového vstupu..."
        echo "Stiskněte displej pro test dotyku (Ctrl+C pro ukončení):"
        timeout 10s evtest /dev/input/event0 2>/dev/null || true
    fi
}

# Hlavní instalační funkce
main_install() {
    log "🚀 ZAHÁJENÍ INSTALACE MHS35 DISPLEJE"
    
    check_privileges
    install_display_dependencies
    install_display_drivers
    configure_display
    configure_homeassistant
    test_display
    
    log "✅ INSTALACE MHS35 DISPLEJE DOKONČENA"
    log "🔄 Pro aplikování změn je nutný restart"
    echo ""
    echo "Pokud chcete systém restartovat nyní, spusťte:"
    echo "sudo reboot"
}

# Zobrazení nápovědy
show_help() {
    echo "Použití: $0 [příkaz]"
    echo ""
    echo "Příkazy:"
    echo "  install     Instalace MHS35 displeje (výchozí)"
    echo "  calibrate   Kalibrace dotykového displeje"
    echo "  test        Testování displeje"
    echo "  help        Zobrazení této nápovědy"
    echo ""
    echo "Příklady:"
    echo "  ./mhs35_setup.sh install"
    echo "  ./mhs35_setup.sh calibrate"
    echo "  ./mhs35_setup.sh test"
}

# Kalibrace displeje
calibrate_display() {
    log "Kalibrace dotykového displeje..."
    
    if command -v xinput_calibrator &> /dev/null; then
        log "Spouštění kalibrace..."
        xinput_calibrator
    else
        log "❌ xinput_calibrator není nainstalován"
        log "Instalujte pomocí: sudo apt-get install xinput-calibrator"
    fi
}

# Hlavní logika
case "${1:-install}" in
    "install")
        main_install
        ;;
    "calibrate")
        calibrate_display
        ;;
    "test")
        test_display
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
