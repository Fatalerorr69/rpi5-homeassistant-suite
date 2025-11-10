#!/bin/bash

# Rychlý skenovací skript pro Home Assistant

echo "🔍 Rychlé skenování Home Assistant"
echo "==================================="

CONFIG_DIR="/config"
SCAN_DATE=$(date +%Y%m%d_%H%M%S)
SCAN_DIR="$CONFIG_DIR/scan_results_$SCAN_DATE"

mkdir -p "$SCAN_DIR"

echo "Skenuji základní informace..."

# Základní systémové informace
{
    echo "Home Assistant Quick Scan Report"
    echo "Generated: $(date)"
    echo "==================================="
    echo ""
    echo "ZÁKLADNÍ INFORMACE:"
    echo "-------------------"
    echo "Config adresář: $CONFIG_DIR"
    echo "Velikost: $(du -sh $CONFIG_DIR | cut -f1)"
    echo ""
} > "$SCAN_DIR/quick_report.txt"

# Struktura adresářů
echo "Analyzuji strukturu adresářů..."
{
    echo "STRUKTURA ADRESÁŘŮ:"
    echo "-------------------"
    find "$CONFIG_DIR" -maxdepth 2 -type d | sort
    echo ""
} >> "$SCAN_DIR/quick_report.txt"

# YAML soubory
echo "Analyzuji YAML soubory..."
{
    echo "YAML SOUBORY:"
    echo "-------------"
    find "$CONFIG_DIR" -name "*.yaml" -o -name "*.yml" | wc -l | xargs echo "Počet YAML souborů:"
    echo ""
    echo "Hlavní konfigurační soubory:"
    ls -la "$CONFIG_DIR"/*.yaml 2>/dev/null | awk '{print $9, $5}'
    echo ""
} >> "$SCAN_DIR/quick_report.txt"

# Custom komponenty
echo "Kontroluji custom komponenty..."
{
    echo "CUSTOM KOMPONENTY:"
    echo "------------------"
    if [ -d "$CONFIG_DIR/custom_components" ]; then
        ls -la "$CONFIG_DIR/custom_components"
        echo ""
        echo "Počet custom komponent: $(ls "$CONFIG_DIR/custom_components" | wc -l)"
    else
        echo "Adresář custom_components neexistuje"
    fi
    echo ""
} >> "$SCAN_DIR/quick_report.txt"

# Automatizace a skripty
echo "Počítám automatizace a skripty..."
{
    echo "AUTOMATIZACE A SKRIPTY:"
    echo "-----------------------"
    AUTOMATION_COUNT=$(grep -r "alias:" "$CONFIG_DIR" --include="*.yaml" --include="*.yml" | wc -l)
    echo "Celkový počet automatizací a skriptů: $AUTOMATION_COUNT"
    echo ""
} >> "$SCAN_DIR/quick_report.txt"

# Docker informace
echo "Kontroluji Docker..."
{
    echo "DOCKER INFORMACE:"
    echo "-----------------"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker není dostupný"
    echo ""
} >> "$SCAN_DIR/quick_report.txt"

# Soubor s příkazy pro další analýzu
cat > "$SCAN_DIR/next_steps.txt" << 'EOF'
DALŠÍ KROKY PRO PODROBNOU ANALÝZU:

1. Podrobný scan Python skriptem:
   python3 /config/full_scan_ha.py

2. Zkontrolovat logy Home Assistant:
   docker logs home-assistant > ha_logs.txt

3. Analýza velikosti souborů:
   find /config -type f -exec du -h {} + | sort -hr | head -20

4. Kontrola YAML validity:
   python3 -c "import yaml; yaml.safe_load(open('/config/configuration.yaml'))"

5. Seznam všech entit:
   grep -r "platform:" /config --include="*.yaml" --include="*.yml"
EOF

echo "✅ Rychlý scan dokončen!"
echo "📄 Report: $SCAN_DIR/quick_report.txt"
echo "📋 Další kroky: $SCAN_DIR/next_steps.txt"

# Zobrazení souhrnu
echo ""
echo "📊 SOUHRN:"
cat "$SCAN_DIR/quick_report.txt" | grep -E "(Počet|Velikost|celkový)" | head -10