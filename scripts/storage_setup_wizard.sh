#!/bin/bash
#
# RPi5 Home Assistant Suite - Interaktivní Storage Wizard
#
# Průvodce pro konfiguraci úložiště podle typu a potřeb:
# - Solo NVMe (jen HA na NVMe)
# - Tiered Storage (NVMe + SSD + HDD)
# - NAS Integration (HA + Network Share)
# - Cloud Backup (S3, Backblaze, NextCloud)
# - Custom Configuration
#
# Použití: ./scripts/storage_setup_wizard.sh
#

set -euo pipefail

# ============================================================================
# KONFIGURACE
# ============================================================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STORAGE_CONFIG="$REPO_ROOT/config/storage_config.yaml"
LOG_FILE="$REPO_ROOT/storage_setup_$(date +%Y%m%d_%H%M%S).log"

# Barevný výstup
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ============================================================================
# UTILITY FUNKCE
# ============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" >> "$LOG_FILE"
}

clear_screen() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   RPi5 Home Assistant - Storage Configuration Wizard            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    local title="$1"
    local -n options=$2
    local default="${3:-1}"
    
    echo -e "${BLUE}$title${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────${NC}"
    
    local i=1
    for option in "${options[@]}"; do
        if [ "$i" -eq "$default" ]; then
            echo -e "${GREEN}[$i] ${option}${NC} ← "
        else
            echo -e "[$i] ${option}"
        fi
        ((i++))
    done
    echo ""
}

get_choice() {
    local prompt="$1"
    local min="${2:-1}"
    local max="${3:-1}"
    local default="${4:-1}"
    local choice
    
    while true; do
        read -p "$(echo -e ${YELLOW}$prompt${NC}) [$default]: " choice
        choice="${choice:-$default}"
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge "$min" ] && [ "$choice" -le "$max" ]; then
            echo "$choice"
            return 0
        fi
        echo -e "${RED}Neplatný výběr - zadejte číslo mezi $min a $max${NC}"
    done
}

get_input() {
    local prompt="$1"
    local default="${2:-}"
    local input
    
    if [ -n "$default" ]; then
        read -p "$(echo -e ${YELLOW}$prompt${NC}) [$default]: " input
        echo "${input:-$default}"
    else
        read -p "$(echo -e ${YELLOW}$prompt${NC}): " input
        echo "$input"
    fi
}

confirm() {
    local prompt="$1"
    local response
    
    read -p "$(echo -e ${YELLOW}$prompt${NC}) (y/n): " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

show_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

show_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

show_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# ============================================================================
# DETEKCE ÚLOŽIŠŤ
# ============================================================================

detect_storage() {
    clear_screen
    echo -e "${BLUE}🔍 Skenování dostupných úložišť...${NC}\n"
    
    local devices_found=()
    
    # NVMe
    if [ -b /dev/nvme0n1 ]; then
        local nvme_size=$(lsblk -b -d -n -o SIZE /dev/nvme0n1 2>/dev/null || echo "0")
        local nvme_human=$(numfmt --to=iec-i --suffix=B $nvme_size 2>/dev/null || echo "N/A")
        show_status "NVMe disk: /dev/nvme0n1 ($nvme_human)"
        devices_found+=("nvme0n1:$nvme_human")
    fi
    
    # SSD/USB
    for disk in /dev/sd[a-z]; do
        if [ -b "$disk" ]; then
            local disk_name=$(basename "$disk")
            local disk_size=$(lsblk -b -d -n -o SIZE "$disk" 2>/dev/null || echo "0")
            local disk_human=$(numfmt --to=iec-i --suffix=B $disk_size 2>/dev/null || echo "N/A")
            
            # Skip root disk
            if ! grep -q "$disk" /etc/fstab 2>/dev/null || [ $(grep -c "$disk" /etc/fstab) -lt 2 ]; then
                show_status "$disk ($disk_human)"
                devices_found+=("$disk_name:$disk_human")
            fi
        fi
    done
    
    # HDD
    if [ -b /dev/sda ]; then
        local sda_size=$(lsblk -b -d -n -o SIZE /dev/sda 2>/dev/null || echo "0")
        local sda_human=$(numfmt --to=iec-i --suffix=B $sda_size 2>/dev/null || echo "N/A")
        show_info "Systémový disk: /dev/sda ($sda_human)"
    fi
    
    # NAS detekce
    if mount | grep -q "nfs\|smb\|cifs"; then
        show_status "NAS/Network share je připojeno"
        mount | grep "nfs\|smb\|cifs" | while read line; do
            echo "  $line"
        done
    fi
    
    echo ""
    read -p "Stiskněte Enter pro pokračování..."
}

# ============================================================================
# SCÉNÁŘ 1: SOLO NVME
# ============================================================================

setup_solo_nvme() {
    clear_screen
    echo -e "${CYAN}═════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  SCÉNÁŘ 1: Solo NVMe Setup${NC}"
    echo -e "${CYAN}═════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    cat <<EOF
${BLUE}Popis:${NC}
• Veškerý Home Assistant běží na NVMe disku
• Maximální výkon
• Vhodné pro malé instalace (< 50 entit)
• Jednoduché nastavení a údržba

${BLUE}Vyžaduje:${NC}
✓ NVMe disk (512GB+ doporučeno)
✓ Dostatek místa pro zálohy

${BLUE}Výhody:${NC}
✓ Jednoduchá správa
✓ Nejrychlejší přístup
✓ Nejmenší složitost

${BLUE}Nevýhody:${NC}
✗ Omezená kapacita (NVMe je drahý)
✗ Bez tiered storage (všechny data na jednom disku)

EOF
    
    if confirm "Pokračovat s Solo NVMe setupem?"; then
        setup_solo_nvme_impl
    fi
}

setup_solo_nvme_impl() {
    clear_screen
    show_info "Nastavuji Solo NVMe..."
    
    # Zvolení mountpoint
    local mount_point=$(get_input "Mount point pro NVMe" "/mnt/nvme")
    
    # Vytvoření struktury
    sudo mkdir -p "$mount_point"/{hass_config,hass_data,hass_media,backups}
    
    # fstab záznam
    local uuid=$(sudo blkid -s UUID -o value /dev/nvme0n1p2 2>/dev/null || echo "auto")
    if [ "$uuid" != "auto" ]; then
        echo "UUID=$uuid $mount_point ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab > /dev/null
        show_status "fstab aktualizován"
    fi
    
    # docker-compose.yml konfigurace
    cat > /tmp/storage_solo_nvme.yaml <<'YAML'
# Solo NVMe Configuration
volumes:
  hass_config:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/nvme/hass_config
  hass_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/nvme/hass_data

services:
  homeassistant:
    volumes:
      - hass_config:/config
      - /etc/localtime:/etc/localtime:ro
      - /mnt/nvme/hass_media:/media
      - /mnt/nvme/backups:/backups

  # MariaDB na NVMe pro максимальный výkon
  mariadb:
    volumes:
      - /mnt/nvme/mariadb_data:/var/lib/mysql
    environment:
      MYSQL_DATABASE: homeassistant
      MYSQL_USER: hass
      MYSQL_PASSWORD: ${DB_PASSWORD}

# Recorder na NVMe SQLite
recorder:
  db_url: sqlite:////mnt/nvme/hass_data/home-assistant_v2.db
  purge_keep_days: 10
  auto_purge: true
YAML
    
    show_status "Konfigurační soubor: /tmp/storage_solo_nvme.yaml"
    
    echo ""
    echo -e "${GREEN}✅ Solo NVMe setup je připraven!${NC}"
    echo ""
    echo "Následující kroky:"
    echo "1. Připojte NVMe disk: sudo mount -a"
    echo "2. Zkopírujte konfiguraci z /tmp/storage_solo_nvme.yaml"
    echo "3. Aktualizujte docker-compose.yml"
    echo "4. Restartujte: docker-compose restart"
    
    log "Solo NVMe setup completed: $mount_point"
}

# ============================================================================
# SCÉNÁŘ 2: TIERED STORAGE
# ============================================================================

setup_tiered_storage() {
    clear_screen
    echo -e "${CYAN}═════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  SCÉNÁŘ 2: Tiered Storage Setup (NVMe + SSD + HDD)${NC}"
    echo -e "${CYAN}═════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    cat <<EOF
${BLUE}Popis:${NC}
• Optimální distribuce dat podle výkonu
• NVMe: Hot data (recorder, cache, TTS)
• SSD: Warm data (config, Docker)
• HDD: Cold data (zálohy, archiv)

${BLUE}Vyžaduje:${NC}
✓ NVMe disk (256GB+)
✓ SSD disk (512GB+)
✓ HDD disk (2TB+, volitelné)

${BLUE}Výhody:${NC}
✓ Optimální výkon + kapacita
✓ Nejlepší poměr cena/výkon
✓ Flexibilní kapacita

${BLUE}Nevýhody:${NC}
✗ Složitější správa
✗ Vyžaduje více disků

EOF
    
    if confirm "Pokračovat s Tiered Storage setupem?"; then
        setup_tiered_storage_impl
    fi
}

setup_tiered_storage_impl() {
    clear_screen
    show_info "Nastavuji Tiered Storage..."
    
    # Výběr disků
    echo ""
    echo -e "${BLUE}Dostupné disky:${NC}"
    lsblk -d -n -o NAME,SIZE,TYPE
    
    echo ""
    local nvme_disk=$(get_input "NVMe disk (např. nvme0n1)" "nvme0n1")
    local ssd_disk=$(get_input "SSD disk (např. sda)" "sda")
    local hdd_disk=$(get_input "HDD disk (volitelný, např. sdb)" "")
    
    # Mount points
    local nvme_mount=$(get_input "NVMe mount point" "/mnt/nvme")
    local ssd_mount=$(get_input "SSD mount point" "/mnt/ssd")
    local hdd_mount=$(get_input "HDD mount point" "/mnt/hdd")
    
    # Vytvoření struktur
    echo ""
    show_info "Vytvářím adresářové struktury..."
    
    # NVMe - HOT tier
    # NVMe - HOT tier
    sudo mkdir -p "$nvme_mount"/{hass_data,hass_cache,docker_volumes,backups/daily}
    
    # SSD - WARM tier
    sudo mkdir -p "$ssd_mount"/{hass_config,docker_data,backups/weekly}
    
    # HDD - COLD tier (pokud je zadán)
    if [ -n "$hdd_disk" ]; then
        sudo mkdir -p "$hdd_mount"/{media_archive,recordings_archive,backups/monthly,historical_data}
        show_status "HDD struktura: $hdd_mount"
    fi
    
    show_status "NVMe struktura: $nvme_mount"
    show_status "SSD struktura: $ssd_mount"
    
    # Generování docker-compose.yml snippet
    cat > /tmp/storage_tiered.yaml <<'YAML'
# Tiered Storage Configuration
# NVMe (HOT): Recorder, Cache, TTS
# SSD (WARM): Config, Docker
# HDD (COLD): Archiv, Backups

volumes:
  hass_config:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/ssd/hass_config
  
  hass_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/nvme/hass_data
  
  hass_cache:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/nvme/hass_cache

services:
  homeassistant:
    volumes:
      - hass_config:/config
      - hass_data:/hass_data
      - /mnt/nvme/docker_volumes/homeassistant:/home/homeassistant/.homeassistant/storage
      - /mnt/hdd/media_archive:/media
      - /mnt/hdd/backups:/backups

  # MariaDB na NVMe (HOT tier)
  mariadb:
    volumes:
      - /mnt/nvme/docker_volumes/mariadb:/var/lib/mysql
    environment:
      MYSQL_DATABASE: homeassistant

  # Node-RED na SSD (WARM tier)
  nodered:
    volumes:
      - /mnt/ssd/docker_data/nodered:/data

# Home Assistant Configuration
recorder:
  db_url: mysql+pymysql://hass:PASSWORD@mariadb/homeassistant?charset=utf8mb4
  purge_keep_days: 30
  auto_purge: true

cache:
  cache_type: redis
  cache_redis_host: redis
  cache_redis_port: 6379

tts:
  platform: google_translate
  cache: true
  cache_dir: /mnt/nvme/hass_cache/tts

homeassistant:
  media_dirs:
    /media: "Media"
YAML
    
    show_status "Konfigurační soubor: /tmp/storage_tiered.yaml"
    
    # Automatické připojování
    echo ""
    show_info "Nastavuji automatické připojování..."
    
    # fstab záznamy
    local nvme_uuid=$(sudo blkid -s UUID -o value "/dev/$nvme_disk" 2>/dev/null || echo "auto")
    local ssd_uuid=$(sudo blkid -s UUID -o value "/dev/$ssd_disk" 2>/dev/null || echo "auto")
    
    if [ "$nvme_uuid" != "auto" ] && [ "$ssd_uuid" != "auto" ]; then
        {
            echo "# Tiered Storage"
            echo "UUID=$nvme_uuid $nvme_mount ext4 defaults,nofail 0 2"
            echo "UUID=$ssd_uuid $ssd_mount ext4 defaults,nofail 0 2"
        } | sudo tee -a /etc/fstab > /dev/null
        show_status "fstab aktualizován"
    fi
    
    if [ -n "$hdd_disk" ]; then
        local hdd_uuid=$(sudo blkid -s UUID -o value "/dev/$hdd_disk" 2>/dev/null || echo "auto")
        if [ "$hdd_uuid" != "auto" ]; then
            echo "UUID=$hdd_uuid $hdd_mount ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab > /dev/null
            show_status "HDD přidán do fstab"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}✅ Tiered Storage je připraven!${NC}"
    echo ""
    echo "Následující kroky:"
    echo "1. Formatujte disky: sudo mkfs.ext4 /dev/{nvme,ssd,hdd}"
    echo "2. Připojte disky: sudo mount -a"
    echo "3. Zkopírujte konfiguraci z /tmp/storage_tiered.yaml"
    echo "4. Aktualizujte docker-compose.yml"
    echo "5. Zkopírujte data: rsync -av /old/path /new/path"
    echo "6. Restartujte: docker-compose restart"
    
    log "Tiered Storage setup: NVMe=$nvme_mount, SSD=$ssd_mount, HDD=$hdd_mount"
}

# ============================================================================
# SCÉNÁŘ 3: NAS INTEGRATION
# ============================================================================

setup_nas_integration() {
    clear_screen
    echo -e "${CYAN}═════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  SCÉNÁŘ 3: NAS Integration${NC}"
    echo -e "${CYAN}═════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    cat <<EOF
${BLUE}Popis:${NC}
• Připojit síťové úložiště (NAS)
• HA běží na lokálním úložišti, zálohy na NAS
• Centralizovaná správa záloh

${BLUE}Podporované:${NC}
✓ SMB/CIFS (Windows shares)
✓ NFS (Linux NAS, QNAP, Synology)
✓ SSH (SFTP)
✓ WebDAV (NextCloud, iCloud)

EOF
    
    if confirm "Pokračovat s NAS integracím?"; then
        setup_nas_impl
    fi
}

setup_nas_impl() {
    clear_screen
    
    # Výběr typu NAS
    local nas_types=("SMB (Windows Share)" "NFS (Linux NAS)" "SFTP (SSH)" "WebDAV" "Zpět")
    local choice=$(get_choice "Vyberte typ NAS:" 1 ${#nas_types[@]} 1)
    
    case "$choice" in
        1)
            setup_nas_smb
            ;;
        2)
            setup_nas_nfs
            ;;
        3)
            setup_nas_sftp
            ;;
        4)
            setup_nas_webdav
            ;;
        5)
            return
            ;;
    esac
}

setup_nas_smb() {
    clear_screen
    show_info "Nastavuji SMB/CIFS..."
    
    local nas_server=$(get_input "NAS adresa (IP nebo hostname)" "192.168.1.100")
    local nas_share=$(get_input "Název share" "backups")
    local nas_user=$(get_input "Uživatelské jméno" "nasuser")
    local nas_pass=$(get_input "Heslo (POZOR - bude viditelné!)" "")
    local mount_point=$(get_input "Mount point" "/mnt/nas_backups")
    
    sudo mkdir -p "$mount_point"
    
    # Instalace nástrojů
    sudo apt-get update
    sudo apt-get install -y cifs-utils
    
    # Mount
    sudo mount -t cifs -o username=$nas_user,password=$nas_pass,iocharset=utf8,file_mode=0755,dir_mode=0755 \
        "//$nas_server/$nas_share" "$mount_point"
    
    # fstab
    local credentials_file="/etc/samba/creds_nas"
    echo "username=$nas_user" | sudo tee "$credentials_file" > /dev/null
    echo "password=$nas_pass" | sudo tee -a "$credentials_file" > /dev/null
    sudo chmod 600 "$credentials_file"
    
    echo "//$nas_server/$nas_share $mount_point cifs credentials=$credentials_file,iocharset=utf8,file_mode=0755,dir_mode=0755,nofail 0 0" | sudo tee -a /etc/fstab > /dev/null
    
    show_status "SMB/CIFS připojeno: $mount_point"
}

setup_nas_nfs() {
    clear_screen
    show_info "Nastavuji NFS..."
    
    local nas_server=$(get_input "NAS adresa (IP)" "192.168.1.100")
    local nas_path=$(get_input "NAS cesta" "/export/backups")
    local mount_point=$(get_input "Mount point" "/mnt/nas_nfs")
    
    sudo mkdir -p "$mount_point"
    sudo apt-get update
    sudo apt-get install -y nfs-common
    
    sudo mount -t nfs "$nas_server:$nas_path" "$mount_point"
    
    echo "$nas_server:$nas_path $mount_point nfs defaults,nofail 0 0" | sudo tee -a /etc/fstab > /dev/null
    
    show_status "NFS připojeno: $mount_point"
}

setup_nas_sftp() {
    clear_screen
    show_info "Nastavuji SFTP..."
    
    local nas_server=$(get_input "Adresa serveru" "192.168.1.100")
    local nas_port=$(get_input "Port" "22")
    local nas_user=$(get_input "Uživatelské jméno" "sftpuser")
    local nas_path=$(get_input "Cesta na serveru" "/backups")
    
    sudo apt-get update
    sudo apt-get install -y sshfs
    
    local mount_point=$(get_input "Mount point" "/mnt/nas_sftp")
    sudo mkdir -p "$mount_point"
    
    # Instalace SSH klíčů
    if confirm "Máte SSH klíč? (y/n)"; then
        local key_file=$(get_input "Cesta k privátnímu klíči" "$HOME/.ssh/id_rsa")
        sshfs -o IdentityFile=$key_file,allow_other,_netdev \
            "$nas_user@$nas_server:$nas_path" "$mount_point"
    else
        show_warn "SSH klíč není nastaven - pro automatické připojování ho nastavte"
    fi
    
    show_status "SFTP připojeno: $mount_point"
}

setup_nas_webdav() {
    clear_screen
    show_info "Nastavuji WebDAV..."
    
    local nas_url=$(get_input "WebDAV URL" "https://nas.example.com/dav")
    local nas_user=$(get_input "Uživatelské jméno" "user")
    local mount_point=$(get_input "Mount point" "/mnt/nas_webdav")
    
    sudo mkdir -p "$mount_point"
    sudo apt-get update
    sudo apt-get install -y davfs2
    
    # Konfigurace
    echo "# WebDAV mount" | sudo tee -a /etc/fstab > /dev/null
    echo "$nas_url $mount_point davfs rw,user,noauto 0 0" | sudo tee -a /etc/fstab > /dev/null
    
    show_status "WebDAV nakonfigurováno: $mount_point"
    show_info "Ruční připojení: sudo mount $mount_point"
}

# ============================================================================
# SCÉNÁŘ 4: CLOUD BACKUP
# ============================================================================

setup_cloud_backup() {
    clear_screen
    echo -e "${CYAN}═════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  SCÉNÁŘ 4: Cloud Backup Setup${NC}"
    echo -e "${CYAN}═════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    cat <<EOF
${BLUE}Popis:${NC}
• Automatické zálohování do cloudu
• Off-site backup pro disaster recovery
• End-to-end šifrování (volitelné)

${BLUE}Podporované:${NC}
✓ AWS S3
✓ Backblaze B2
✓ Google Drive
✓ Dropbox
✓ MinIO (S3-compatible)

EOF
    
    if confirm "Pokračovat s Cloud Backup?"; then
        setup_cloud_backup_impl
    fi
}

setup_cloud_backup_impl() {
    clear_screen
    
    local cloud_providers=("AWS S3" "Backblaze B2" "Google Drive" "Dropbox" "MinIO" "Zpět")
    local choice=$(get_choice "Vyberte Cloud poskytovatele:" 1 ${#cloud_providers[@]} 1)
    
    case "$choice" in
        1) setup_backup_s3 ;;
        2) setup_backup_b2 ;;
        3) setup_backup_gdrive ;;
        4) setup_backup_dropbox ;;
        5) setup_backup_minio ;;
        6) return ;;
    esac
}

setup_backup_s3() {
    show_info "AWS S3 konfigurace - TODO"
}

setup_backup_b2() {
    show_info "Backblaze B2 konfigurace - TODO"
}

setup_backup_gdrive() {
    show_info "Google Drive konfigurace - TODO"
}

setup_backup_dropbox() {
    show_info "Dropbox konfigurace - TODO"
}

setup_backup_minio() {
    show_info "MinIO konfigurace - TODO"
}

# ============================================================================
# CUSTOM KONFIGURACE
# ============================================================================

setup_custom() {
    clear_screen
    echo -e "${CYAN}═════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Custom Storage Configuration${NC}"
    echo -e "${CYAN}═════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    show_info "V custom režimu můžete kombinovat různé úložiště"
    echo ""
    
    # Vytvoření custom config
    cat > "$STORAGE_CONFIG" <<'YAML'
# Custom Storage Configuration
# Upravte podle vašich potřeb

storage_setup:
  name: "Custom Setup"
  description: "Vaše vlastní konfigurace"
  
  tiers:
    hot:
      type: "nvme"
      device: "/dev/nvme0n1"
      mount: "/mnt/nvme"
      purpose: "Recorder, Cache, TTS"
      
    warm:
      type: "ssd"
      device: "/dev/sda"
      mount: "/mnt/ssd"
      purpose: "Config, Docker"
      
    cold:
      type: "hdd"
      device: "/dev/sdb"
      mount: "/mnt/hdd"
      purpose: "Archiv, Backups"
  
  backups:
    local:
      path: "/mnt/nvme/backups"
      retention: "7d"
      
    external:
      type: "nas"  # smb, nfs, sftp
      location: "192.168.1.100:/backups"
      retention: "30d"
YAML
    
    show_status "Custom config uložen: $STORAGE_CONFIG"
    echo ""
    echo "Další kroky:"
    echo "1. Upravte: $STORAGE_CONFIG"
    echo "2. Spusťte: ./scripts/storage_apply.sh"
}

# ============================================================================
# SOUHRN KONFIGURACE
# ============================================================================

show_summary() {
    clear_screen
    echo -e "${CYAN}═════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Souhrn Konfigurace${NC}"
    echo -e "${CYAN}═════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ -f "$STORAGE_CONFIG" ]; then
        echo -e "${GREEN}Konfigurace:${NC}"
        cat "$STORAGE_CONFIG"
        echo ""
    fi
    
    echo -e "${BLUE}Důležité:${NC}"
    echo "1. Zkontrolujte fstab: cat /etc/fstab"
    echo "2. Připojte disky: sudo mount -a"
    echo "3. Ověřte spojení: df -h"
    echo "4. Zkopírujte data: rsync -av /old /new"
    echo "5. Aktualizujte docker-compose.yml"
    echo "6. Restartujte: docker-compose restart"
    echo ""
    echo "Log soubor: $LOG_FILE"
}

# ============================================================================
# HLAVNÍ MENU
# ============================================================================

main_menu() {
    while true; do
        clear_screen
        
        echo -e "${BLUE}Co chcete konfigurovat?${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────${NC}"
        echo ""
        
        local menu_options=(
            "🔍 Detekovat dostupná úložiště"
            "⚡ Solo NVMe Setup"
            "📊 Tiered Storage (NVMe + SSD + HDD)"
            "🌐 NAS Integration"
            "☁️  Cloud Backup Setup"
            "🎨 Custom Configuration"
            "📋 Zobrazit Souhrn"
            "🚀 Aplikovat Konfiguraci"
            "❌ Ukončit"
        )
        
        show_menu "Hlavní Menu:" menu_options
        
        local choice=$(get_choice "Vyberte:" 1 ${#menu_options[@]} 1)
        
        case "$choice" in
            1) detect_storage ;;
            2) setup_solo_nvme ;;
            3) setup_tiered_storage ;;
            4) setup_nas_integration ;;
            5) setup_cloud_backup ;;
            6) setup_custom ;;
            7) show_summary ;;
            8) apply_storage_config ;;
            9)
                echo -e "${GREEN}Děkuji za použití Storage Wizardu!${NC}"
                exit 0
                ;;
        esac
    done
}

apply_storage_config() {
    clear_screen
    show_info "Aplikuji Storage konfiguraci..."
    
    # Připojení všech disků
    if sudo mount -a; then
        show_status "Všechny disky připojeny"
    else
        show_error "Chyba při připojování disků"
        return 1
    fi
    
    # Ověření
    echo ""
    echo -e "${BLUE}Připojená úložiště:${NC}"
    df -h | grep /mnt
    
    log "Storage configuration applied successfully"
    show_status "Konfigurace aplikována"
}

# ============================================================================
# START
# ============================================================================

# Kontrola sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Wizard vyžaduje sudo - restartuje se...${NC}"
    exec sudo bash "$0" "$@"
fi

log "Storage Setup Wizard started"
main_menu
log "Storage Setup Wizard completed"
