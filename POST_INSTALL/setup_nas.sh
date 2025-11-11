#!/bin/bash
set -euo pipefail

# Barvy
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
err() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }

setup_nas() {
    log "🗄️ Konfigurace NAS úložiště..."
    
    read -p "Zvol typ NAS (1=Samba/CIFS, 2=NFS): " nas_type
    
    case $nas_type in
        1)
            setup_samba
            ;;
        2)
            setup_nfs
            ;;
        *)
            warn "Neplatná volba, přeskočeno"
            return 1
            ;;
    esac
}

setup_samba() {
    log "Nastavení Samba/CIFS..."
    
    read -p "Zadej IP NAS serveru: " nas_ip
    read -p "Zadej sdílenou složku: " share_name
    read -p "Zadej uživatelské jméno (nech prázdné pro guest): " username
    read -s -p "Zadej heslo: " password
    echo
    
    # Vytvoření připojovacího bodu
    sudo mkdir -p /mnt/nas
    
    # Příprava přihlašovacích údajů
    if [[ -n "$username" ]]; then
        echo "username=$username" | sudo tee /etc/.nas_credentials > /dev/null
        echo "password=$password" | sudo tee -a /etc/.nas_credentials > /dev/null
        sudo chmod 600 /etc/.nas_credentials
        
        mount_cmd="sudo mount -t cifs //$nas_ip/$share_name /mnt/nas -o credentials=/etc/.nas_credentials,uid=1000,gid=1000"
    else
        mount_cmd="sudo mount -t cifs //$nas_ip/$share_name /mnt/nas -o guest,uid=1000,gid=1000"
    fi
    
    # Připojení
    if $mount_cmd; then
        log "✅ Samba úspěšně připojena"
        
        # Přidání do fstab pro trvalé připojení
        if [[ -n "$username" ]]; then
            echo "//$nas_ip/$share_name /mnt/nas cifs credentials=/etc/.nas_credentials,uid=1000,gid=1000 0 0" | sudo tee -a /etc/fstab
        else
            echo "//$nas_ip/$share_name /mnt/nas cifs guest,uid=1000,gid=1000 0 0" | sudo tee -a /etc/fstab
        fi
    else
        err "❌ Chyba připojování Samba"
    fi
}

setup_nfs() {
    log "Nastavení NFS..."
    
    read -p "Zadej IP NAS serveru: " nas_ip
    read -p "Zadej sdílenou složku: " share_name
    
    # Instalace NFS klienta
    sudo apt install -y nfs-common
    
    # Vytvoření připojovacího bodu
    sudo mkdir -p /mnt/nas
    
    # Připojení
    if sudo mount -t nfs $nas_ip:/$share_name /mnt/nas; then
        log "✅ NFS úspěšně připojena"
        
        # Přidání do fstab
        echo "$nas_ip:/$share_name /mnt/nas nfs defaults 0 0" | sudo tee -a /etc/fstab
    else
        err "❌ Chyba připojování NFS"
    fi
}

main() {
    setup_nas
}

main "$@"