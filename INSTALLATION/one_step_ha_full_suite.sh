#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$HOME/rpi5_ha_full_suite_debian13"
ZIP_FILE="$HOME/rpi5_ha_full_suite_debian13.zip"

echo "=== ONE-STEP Home Assistant Full Suite Installer ==="

# -----------------------------
# Kontrola platformy
# -----------------------------
ARCH=$(uname -m)
OS=$(lsb_release -cs)
if [ "$ARCH" != "aarch64" ]; then
    echo "❌ Chyba: Tento skript je určen pro Raspberry Pi 5 (ARM64)"
    exit 1
fi
if [ "$OS" != "trixie" ]; then
    echo "⚠️ Doporučeno Debian 13 Trixie. Pokračuješ na $OS."
fi

# -----------------------------
# Vytvoření struktury a souborů
# -----------------------------
echo "📁 Vytvářím adresáře..."
mkdir -p "$ROOT_DIR/postinstall" "$ROOT_DIR/templates"

# Hlavní instalační skript
cat > "$ROOT_DIR/install_full_suite.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
echo "=== Spouštím instalaci HA Full Suite ==="

sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git jq docker.io docker-compose network-manager \
    dbus udisks2 apparmor avahi-daemon python3 python3-pip

sudo mkdir -p /mnt/vm /mnt/nas /srv/devtools
sudo chown -R $(whoami):$(whoami) /mnt/vm /mnt/nas /srv/devtools

for script in postinstall/*.sh; do
    echo "🔧 Spouštím $script..."
    bash "$script"
done

echo "✅ Instalace dokončena."
read -p "Stiskni Enter pro restart systému, nebo Ctrl+C pro odložení..." dummy
sudo reboot
EOF
chmod +x "$ROOT_DIR/install_full_suite.sh"

# Postinstall skripty
declare -A POSTINSTALL=(
["install_addons.sh"]='#!/usr/bin/env bash
set -euo pipefail
echo "📦 Instalace doplňků HA..."
declare -a addons=("core_ssh" "core_configurator" "core_samba" "a0d7b954_portainer" "a0d7b954_vscode" "hassio_vmm" "local_backupmgr")
for addon in "${addons[@]}"; do
    echo "→ Instalace $addon..."
    ha addons install "$addon" || echo "❌ Chyba instalace $addon"
    ha addons start "$addon" || echo "⚠️ Není možné automaticky spustit $addon"
done
'
["setup_storage.sh"]='#!/usr/bin/env bash
set -euo pipefail
echo "🗄️ Konfigurace NAS úložiště..."
read -p "Zvol typ NAS (1=Samba/CIFS, 2=NFS): " type
read -p "Zadej IP NAS serveru: " NAS_IP
read -p "Zadej sdílenou složku: " NAS_SHARE
if [ "$type" = "1" ]; then
    sudo apt install -y cifs-utils
    sudo mount -t cifs //$NAS_IP/$NAS_SHARE /mnt/nas -o username=guest,password=
elif [ "$type" = "2" ]; then
    sudo apt install -y nfs-common
    sudo mount -t nfs $NAS_IP:/$NAS_SHARE /mnt/nas
else
    echo "❌ Neznámý typ NAS, přeskočeno"
fi
echo "✅ NAS připojeno do /mnt/nas"
'
["setup_vmspace.sh"]='#!/usr/bin/env bash
set -euo pipefail
echo "💻 Konfigurace VM prostoru..."
read -p "Zvol typ virtualizace (1=QEMU/libvirt, 2=VirtualBox ARM): " vmtype
if [ "$vmtype" = "1" ]; then
    sudo apt install -y qemu qemu-kvm libvirt-daemon-system libvirt-clients virt-manager
elif [ "$vmtype" = "2" ]; then
    echo "⚠️ VirtualBox ARM musí být ručně nainstalován, tento skript nastaví jen adresáře."
fi
echo "✅ VM prostor připraven v /mnt/vm"
'
["setup_devtools.sh"]='#!/usr/bin/env bash
set -euo pipefail
echo "🛠️ Instalace DevTools..."
sudo apt install -y code python3-venv python3-pip git
echo "✅ Vývojové nástroje připraveny v /srv/devtools"
'
["setup_supervised_env.sh"]='#!/usr/bin/env bash
set -euo pipefail
echo "🌀 Aktivace Home Assistant Supervised..."
curl -sL https://raw.githubusercontent.com/home-assistant/supervised-installer/master/installer.sh | bash
echo "✅ Supervised aktivován, vývojový režim a Supervisor funkční"
'
)

for f in "${!POSTINSTALL[@]}"; do
    echo "${POSTINSTALL[$f]}" > "$ROOT_DIR/postinstall/$f"
    chmod +x "$ROOT_DIR/postinstall/$f"
done

# Templates
declare -A TEMPLATES=(
["docker-compose.yml.tmpl"]='version: "3"
services:
  homeassistant:
    container_name: homeassistant
    image: ghcr.io/home-assistant/home-assistant:stable
    restart: unless-stopped
    network_mode: host
    volumes:
      - /mnt/vm:/mnt/vm
      - /mnt/nas:/mnt/nas
      - /srv/devtools:/srv/devtools
      - /etc/localtime:/etc/localtime:ro
'
["ha_supervised.conf"]='homeassistant:
  development: true
  supervisor: true
  virtual_env: true
'
["vm_example.qemu"]='# Vzorový obraz QEMU pro testování VM
# Uložit do /mnt/vm/ a spustit pomocí qemu-system-aarch64
'
["smb_nas_example.conf"]='# Vzor pro NAS připojení CIFS
# //192.168.1.100/share /mnt/nas cifs username=guest,password=,iocharset=utf8 0 0
'
)

for f in "${!TEMPLATES[@]}"; do
    echo "${TEMPLATES[$f]}" > "$ROOT_DIR/templates/$f"
done

# -----------------------------
# ZIP balíček
# -----------------------------
echo "📦 Vytvářím ZIP archiv $ZIP_FILE..."
cd "$HOME"
zip -r "$ZIP_FILE" "$(basename $ROOT_DIR)" > /dev/null
echo "✅ ZIP archiv vytvořen: $ZIP_FILE"

# -----------------------------
# Spuštění hlavní instalace
# -----------------------------
echo "🚀 Spouštím hlavní instalační skript..."
bash "$ROOT_DIR/install_full_suite.sh"

