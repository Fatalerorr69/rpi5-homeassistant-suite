#!/bin/bash
# one_step_fullsuite_starkos_mhs35_interactive.sh
# Kompletní interaktivní instalace StarkOS + MHS35 TFT Display (RPi5, Debian 13)
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
git clone https://github.com/goodtft/LCD-show.git
chmod -R 755 LCD-show
cd LCD-show
sudo ./MHS35-show 270

# Alternativně:
sudo ./LCD35-show

------------------------------------------------------

# Odinstalace:
chmod -R 755 LCD-show
cd LCD-show/
sudo ./LCD-hdmi

------------------------------------------------------

# Otočení displeje:
cd LCD-show/
sudo ./rotate.sh 90
# Hodnotu „90“ lze změnit na 0, 90, 180, 270.

------------------------------------------------------

# Manuální konfigurace:
v /boot/config.txt přidejte:
dtparam=spi=on
dtoverlay=piscreen,drm,rotate=180

# V raspi-config:
Interface → SPI → Enable
Advanced → Wayland → X11 (Legacy)
→ Reboot
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
            if [[ -f "$HOME/setup_mhs35_auto_dpi.sh" ]]; then
                sudo bash "$HOME/setup_mhs35_auto_dpi.sh"
                echo -e "${GREEN}✅ Automatická instalace dokončena${RESET}"
            else
                echo -e "${RED}⚠️ Automatický skript nebyl nalezen!${RESET}"
            fi
            ;;
        2)
            less "$EXTRAS_DIR/RPI5-MHS_displej_install-uninstall.txt"
            ;;
        3)
            read -rp "Zadejte úhel rotace (0,90,180,270): " angle
            if [[ "$angle" =~ ^(0|90|180|270)$ ]]; then
                cd "$EXTRAS_DIR/LCD-show" 2>/dev/null || echo -e "${RED}LCD-show adresář nenalezen${RESET}" && continue
                sudo ./rotate.sh "$angle"
                echo -e "${GREEN}✅ Displej otočen na $angle°${RESET}"
            else
                echo -e "${RED}Neplatná hodnota!${RESET}"
            fi
            ;;
        4)
            cd "$EXTRAS_DIR/LCD-show" 2>/dev/null || echo -e "${RED}LCD-show adresář nenalezen${RESET}" && continue
            sudo ./LCD-hdmi
            echo -e "${GREEN}✅ MHS35 odinstalován${RESET}"
            ;;
        5)
            echo -e "${BLUE}Otevírám /boot/config.txt pro úpravy...${RESET}"
            sudo nano /boot/config.txt
            echo -e "${BLUE}Pro aktivaci SPI a X11 použijte: sudo raspi-config${RESET}"
            ;;
        6)
            less "$EXTRAS_DIR/starkos_instructions.txt"
            ;;
        7)
            echo -e "${BLUE}Ukončuji...${RESET}"
            break
            ;;
        *)
            echo -e "${RED}Neplatná volba, zkuste znovu.${RESET}"
            ;;
    esac
done

echo -e "${BOLD}${CYAN}=== KONEC INTERAKTIVNÍ INSTALACE ===${RESET}"
