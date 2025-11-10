# Projektová struktura - RPi5 Home Assistant Suite

## 🏗️ Architektura

INSTALLATION/ - Instalační skripty
HARDWARE/ - Ovladače a nastavení hardware
CONFIG/ - Konfigurační soubory HA
STORAGE/ - Správa úložišť
DIAGNOSTICS/ - Diagnostické nástroje
POST_INSTALL/ - Post-instalační úkoly
TEMPLATES/ - Konfigurační šablony

## 🔄 Workflow

1. **INSTALACE** → INSTALLATION/setup_master.sh
2. **KONFIGURACE** → CONFIG/ + auto_install.sh  
3. **OPTIMALIZACE** → STORAGE/ + POST_INSTALL/
4. **DIAGNOSTIKA** → DIAGNOSTICS/
5. **ÚDRŽBA** → repair scripts + health dashboard
