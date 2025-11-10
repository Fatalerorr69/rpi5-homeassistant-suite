#!/bin/bash
# one_step_fullsuite_starkos_mhs35_interactive_auto.sh
# Kompletní interaktivní instalace StarkOS + MHS35 TFT Display (RPi5, Debian 13)
# Automatické stažení chybějících souborů
# Autor: Starko, 2025
# ===================================================================

set -euo pipefail
IFS=$'\n\t'

# -------------------------- ANSI barvy --------------------------
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

LOG_FILE="$HOME/one_step_fullsuite_starkos_mhs35.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${BOLD}${CYAN}=== One-step Full Suite StarkOS + MHS35 (INTERACTIVE) ===${RESET}"
echo -e "${YELLOW}Datum spuštění: $(date)${RESET}\n"

# -------------------------- Vytvoření složky extras --------------------------
EXTRAS_DIR="$HOME/extras"
mkdir -p "$EXTRAS_DIR"
echo -e "${GREEN}✅ Vytvořena složka pro doplňkové soubory: $EXTRAS_DIR${RESET}"

# -------------------------- Kontrola a stažení LCD-show --------------------------
LCD_DIR="$EXTRAS_DIR/LCD-show"
if [[ ! -d "$LCD_DIR" ]]; then
    echo -e "${BLUE}LCD-show adresář nenalezen, stahuji z GitHubu...${RESET}"
    git clone https://github.com/goodtft/LCD-show.git "$LCD_DIR"
    chmod -R 755 "$LCD_DIR"
    echo -e "${GREEN}✅ LCD-show stažen a připraven${RESET}"
else
    echo -e "${GREEN}✅ LCD-show již existuje${RESET}"
fi

# -------------------------- Kontrola a stažení setup_mhs35_auto_dpi.sh --------------------------
SETUP_SCRIPT="$HOME/setup_mhs35_auto_dpi.sh"
if [[ ! -f "$SETUP_SCRIPT" ]]; then
    echo -e "${BLUE}setup_mhs35_auto_dpi.sh nebyl nalezen, stahuji...${RESET}"
    curl -fsSL -o "$SETUP_SCRIPT" "https://raw.githubusercontent.com/Fatalerorr69/rpi5-starkhost/main/setup_mhs35_auto_dpi.sh"
    chmod +x "$SETUP_SCRIPT"
    echo -e "${GREEN}✅ setup_mhs35_auto_dpi.sh stažen a připraven${RESET}"
else
    echo -e "${GREEN}✅ setup_mhs35_auto_dpi.sh již existuje${RESET}"
fi

# -------------------------- Vytvoření instrukcí --------------------------
# StarkOS instrukce
cat > "$EXTRAS_DIR/starkos_instructions.txt" <<'EOF'
=== StarkOS - Kompletní instalace a spuštění ===
# ... sem vlož obsah tvého StarkOS návodu ...
EOF

# MHS35 Auto
cat > "$EXTRAS_DIR/RPI5-MHS35_auto_install.txt" <<'EOF'
=== Automatická instalace MHS35 ===
# Spustit automatický setup script:
# sudo ./setup_mhs35_auto_dpi.sh
# Tento skript provede:
# - detekci RPi5
# - nastavení DPI a rozlišení
# - konfiguraci Waydroid/StarkOS integrace
EOF

# MHS35 Manual
cat > "$EXTRAS_DIR/RPI5-MHS_displej_install-uninstall.txt" <<'EOF'
=== Ruční instalace/odinstalace MHS35 (GoodTFT) ===
# Instalace ovladače:
sudo rm -rf LCD-show
cd LCD-show
sudo ./MHS35-show 270
# Alternativně: sudo ./LCD35-show
# Odinstalace: sudo ./LCD-hdmi
# Rotace displeje: sudo ./rotate.sh 90 (0,90,180,270)
# Manuální konfigurace: dtparam=spi=on, dtoverlay=piscreen,drm,rotate=180
# Aktivace SPI/X11: sudo raspi-config
EOF

echo -e "${GREEN}✅ Vytvořeny všechny instrukce${RESET}"

# -------------------------- Vytvoření ZIP zálohy --------------------------
ZIP_FILE="$HOME/starkos_mhs35_extras.zip"
cd "$EXTRAS_DIR"
zip -r "$ZIP_FILE" ./* > /dev/null
echo -e "${GREEN}✅ Vytvořen ZIP archiv: $ZIP_FILE${RESET}"

# -------------------------- Interaktivní menu --------------------------
while true; do
    echo -e "\n${BOLD}${CYAN}=== Interaktivní Menu ===${RESET}"
    echo -e "${YELLOW}1) Spustit automatickou instalaci MHS35${RESET}"
    echo -e "${YELLOW}2) Zobrazit ruční návod MHS35${RESET}"
    echo -e "${YELLOW}3) Otočení displeje${RESET}"
    echo -e "${YELLOW}4) Odinstalace MHS35${RESET}"
    echo -e "${YELLOW}5) Úprava /boot/config.txt a SPI/X11${RESET}"
    echo -e "${YELLOW}6) Zobrazit StarkOS instrukce${RESET}"
    echo -e "${YELLOW}7) Ukončit${RESET}"
    read -rp "Volba [1-7]: " choice

    case "$choice" in
        1)
            echo -e "${BLUE}Spouštím automatickou instalaci MHS35...${RESET}"
            sudo bash "$SETUP_SCRIPT"
            echo -e "${GREEN}✅ Automatická instalace dokončena${RESET}"
            ;;
        2)
            less "$EXTRAS_DIR/RPI5-MHS_displej_install-uninstall.txt"
            ;;
        3)
            read -rp "Zadejte úhel rotace (0,90,180,270): " angle
            if [[ "$angle" =~ ^(0|90|180|270)$ ]]; then
                cd "$LCD_DIR"
                sudo ./rotate.sh "$angle"
                echo -e "${GREEN}✅ Displej otočen na $angle°${RESET}"
            else
                echo -e "${RED}Neplatná hodnota!${RESET}"
            fi
            ;;
        4)
            cd "$LCD_DIR"
            sudo ./LCD-hdmi
            echo -e "${GREEN}✅ MHS35 odinstalován${RESET}"
            ;;
        5)
            echo -e "${BLUE}Otevírám /boot/config.txt pro úpravy...${RESET}"
            sudo n
