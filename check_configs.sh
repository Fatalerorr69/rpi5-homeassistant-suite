#!/bin/bash

echo "🔍 KONTROLA KONFIGURAČNÍCH SOUBORŮ"
echo "===================================="

# Funkce pro kontrolu YAML
check_yaml() {
    local file=$1
    echo -n "Kontrola $file... "
    if [ -f "$file" ]; then
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            echo "✅"
            return 0
        else
            echo "❌ CHYBA: Neplatný YAML"
            return 1
        fi
    else
        echo "⚠️  SOUBOR NEEXISTUJE"
        return 2
    fi
}

# Funkce pro kontrolu adresáře
check_dir() {
    local dir=$1
    echo -n "Kontrola $dir... "
    if [ -d "$dir" ]; then
        echo "✅"
        return 0
    else
        echo "⚠️  ADRESÁŘ NEEXISTUJE - vytvářím"
        mkdir -p "$dir"
        return 1
    fi
}

# Funkce pro kontrolu skriptu
check_script() {
    echo "🔧 KONTROLA SKRIPTŮ"
scripts=("setup_master.sh" "install.sh" "mhs35_setup.sh" "check_configs.sh" "cleanup_previous.sh")

for script in "${scripts[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            echo "✅ $script (spustitelný)"
        else
            echo "⚠️  $script (nastavuji spustitelný)"
            chmod +x "$script"
        fi
    else
        echo "❌ $script (chybí)"
    fi
done
}

echo ""
echo "📁 KONTROLA ADRESÁŘOVÉ STRUKTURY:"
check_dir "config"
check_dir "config/mosquitto"
check_dir "config/mosquitto/data"
check_dir "config/mosquitto/log"
check_dir "config/zigbee2mqtt"
check_dir "config/node-red"
check_dir "config/node-red/data"
check_dir "config/portainer"
check_dir "config/portainer/data"

echo ""
echo "📄 KONTROLA KONFIGURAČNÍCH SOUBORŮ:"
check_yaml "docker-compose.yml"
check_yaml "config/configuration.yaml"
check_yaml "config/zigbee2mqtt/configuration.yaml"

echo ""
echo "🔧 KONTROLA SKRIPTŮ:"
check_script "setup_master.sh"
check_script "check_configs.sh"
check_script "install.sh"
check_script "mhs35_setup.sh"

echo ""
echo "🐳 KONTROLA DOCKER:"
if command -v docker &> /dev/null; then
    echo "✅ Docker je nainstalován"
    echo "   Verze: $(docker --version)"
else
    echo "❌ Docker není nainstalován"
fi

if command -v docker-compose &> /dev/null; then
    echo "✅ Docker Compose je nainstalován"
    echo "   Verze: $(docker-compose --version)"
else
    echo "❌ Docker Compose není nainstalován"
fi

echo ""
echo "🎯 KONTROLA DOKONČENA"
echo "===================================="
