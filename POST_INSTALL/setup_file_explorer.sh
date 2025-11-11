#!/bin/bash
# Setup file explorer/manager for browsing config and data directories
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config"
BACKUPS_DIR="$REPO_ROOT/backups"

echo "=== File Explorer Setup ==="
echo "Vyberte si způsob přístupu k souborům:"
echo "1) Samba (Windows/Mac/Linux network share)"
echo "2) SFTP (SSH file transfer)"
echo "3) Lokalní správce souborů (Nauítilus/Thunar/Dolphin)"
echo "4) Web UI (simple HTTP file browser)"
read -p "Vyberte [1-4]: " choice

case "$choice" in
    1)
        echo "Instalace Samby..."
        sudo apt-get update
        sudo apt-get install -y samba samba-common-bin
        
        # Backup original smb.conf
        sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
        
        # Přidat share pro config a backups
        cat | sudo tee -a /etc/samba/smb.conf <<EOF

[homeassistant-config]
   comment = Home Assistant Config
   path = $CONFIG_DIR
   readonly = no
   guest ok = no
   valid users = $(whoami)
   create mask = 0755
   directory mask = 0755

[homeassistant-backups]
   comment = Home Assistant Backups
   path = $BACKUPS_DIR
   readonly = no
   guest ok = no
   valid users = $(whoami)
   create mask = 0755
   directory mask = 0755
EOF

        # Přidat uživatele do Samby
        echo "Nastavte Samba heslo pro uživatele $(whoami):"
        sudo smbpasswd -a $(whoami)
        
        sudo systemctl restart smbd nmbd
        echo "✅ Samba nainstalována a nakonfigurována"
        echo "Připojte se: \\\\$(hostname -I | awk '{print $1}')\\homeassistant-config"
        ;;
    2)
        echo "SFTP je již dostupné přes SSH"
        echo "Použijte: sftp -r user@$(hostname -I | awk '{print $1}'):$CONFIG_DIR"
        echo "✅ SFTP ready"
        ;;
    3)
        echo "Instalace lokálního správce souborů..."
        sudo apt-get update
        
        # Vybrat dostupný správce
        if command -v nautilus &>/dev/null; then
            echo "✅ Nautilus (GNOME) je již nainstalován"
            nautilus "$CONFIG_DIR" &
        elif command -v thunar &>/dev/null; then
            echo "✅ Thunar (Xfce) je již nainstalován"
            thunar "$CONFIG_DIR" &
        elif command -v dolphin &>/dev/null; then
            echo "✅ Dolphin (KDE) je již nainstalován"
            dolphin "$CONFIG_DIR" &
        else
            echo "Instalace Thunar (lehký správce)..."
            sudo apt-get install -y thunar
            thunar "$CONFIG_DIR" &
        fi
        ;;
    4)
        echo "Instalace HTTP file browser..."
        sudo apt-get update
        sudo apt-get install -y python3-http-server
        
        echo "✅ HTTP file browser:"
        echo "Spusťte: cd $CONFIG_DIR && python3 -m http.server 8888"
        echo "Přístup: http://localhost:8888"
        echo "Nebo: http://$(hostname -I | awk '{print $1}'):8888"
        ;;
    *)
        echo "Neplatná volba"
        exit 1
        ;;
esac

echo ""
echo "Setup dokončen!"
