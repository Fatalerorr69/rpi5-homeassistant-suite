#!/bin/bash
#
# RPi5 Home Assistant Suite - Automatické Připojování Úložišť
#
# Nastaví systemd jednotky pro automatické připojování externích disků
# s fallback a health check mechanismy
#
# Použití: sudo ./POST_INSTALL/setup_storage_auto_mount.sh
#

set -euo pipefail

# ============================================================================
# KONFIGURACE
# ============================================================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$REPO_ROOT/storage_automount_$(date +%Y%m%d_%H%M%S).log"

# Barevný výstup
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# UTILITY FUNKCE
# ============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}ℹ️  $@${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}✅ $@${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}❌ $@${NC}" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $@${NC}" | tee -a "$LOG_FILE"
}

log_section() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}$@${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
}

# Kontrola sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Skript musí běžet jako root (sudo)"
        exit 1
    fi
}

# ============================================================================
# KONFIGURACE SYSTEMD JEDNOTEK
# ============================================================================

create_mount_unit() {
    local device_uuid="$1"
    local mount_point="$2"
    local fstype="${3:-ext4}"
    local unit_name="$(basename "$mount_point" | tr '/' '_')"
    
    log_info "Vytvářím systemd mount unit: $unit_name"
    
    # Vytvoření .mount souboru
    cat > "/etc/systemd/system/$unit_name.mount" <<UNIT
[Unit]
Description=Automatické připojování $mount_point
Documentation=https://github.com/Fatalerorr69/rpi5-homeassistant-suite
After=network-online.target
Wants=network-online.target

[Mount]
What=UUID=$device_uuid
Where=$mount_point
Type=$fstype
Options=defaults,nofail,x-systemd.device-timeout=30

[Install]
WantedBy=local-fs.target
UNIT
    
    log_success "Systemd unit vytvořen: $unit_name.mount"
}

create_automount_unit() {
    local mount_point="$1"
    local unit_name="$(basename "$mount_point" | tr '/' '_')"
    
    log_info "Vytvářím systemd automount unit: $unit_name"
    
    # Vytvoření .automount souboru pro on-demand připojení
    cat > "/etc/systemd/system/$unit_name.automount" <<UNIT
[Unit]
Description=Automatické on-demand připojování $mount_point
Documentation=https://github.com/Fatalerorr69/rpi5-homeassistant-suite
After=network-online.target

[Automount]
Where=$mount_point
TimeoutIdleSec=15min

[Install]
WantedBy=local-fs.target
UNIT
    
    log_success "Automount unit vytvořen: $unit_name.automount"
}

# ============================================================================
# HEALTH CHECK SKRIPT
# ============================================================================

create_health_check_service() {
    log_section "Vytváření Health Check Služby"
    
    # Vytvoření health check skriptu
    cat > "/usr/local/bin/storage-health-check.sh" <<'SCRIPT'
#!/bin/bash
# Health check pro připojená úložiště
set -euo pipefail

LOG_FILE="/var/log/storage-health-check.log"
ALERT_FILE="/tmp/storage-health-alert"
MOUNT_POINTS=("$@")

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" >> "$LOG_FILE"
}

check_mount_point() {
    local mount_point="$1"
    
    if ! mountpoint -q "$mount_point"; then
        log "⚠️  WARNING: $mount_point je ODPOJENO"
        echo "$mount_point" >> "$ALERT_FILE"
        
        # Pokus o automatické připojení
        log "🔄 Pokouším se znovu připojit $mount_point"
        if mount "$mount_point" 2>/dev/null; then
            log "✅ $mount_point úspěšně znovu připojeno"
            return 0
        else
            log "❌ CHYBA: Nelze připojit $mount_point"
            return 1
        fi
    else
        log "✅ $mount_point OK"
        return 0
    fi
}

check_disk_space() {
    local mount_point="$1"
    local warning_percent=85
    local critical_percent=95
    
    local usage=$(df "$mount_point" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$usage" -ge "$critical_percent" ]; then
        log "🚨 CRITICAL: $mount_point je z $usage% (limit: $critical_percent%)"
        return 2
    elif [ "$usage" -ge "$warning_percent" ]; then
        log "⚠️  WARNING: $mount_point je z $usage% (limit: $warning_percent%)"
        return 1
    else
        log "✅ $mount_point spacing OK ($usage%)"
        return 0
    fi
}

check_inodes() {
    local mount_point="$1"
    local warning_percent=80
    
    local inodes=$(df -i "$mount_point" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$inodes" -ge "$warning_percent" ]; then
        log "⚠️  WARNING: $mount_point má málo inodů ($inodes%)"
        return 1
    else
        log "✅ $mount_point inodes OK ($inodes%)"
        return 0
    fi
}

# Skenování všech /mnt/XX mount pointů
> "$ALERT_FILE"

for mount_point in /mnt/*; do
    if mountpoint -q "$mount_point" 2>/dev/null; then
        check_mount_point "$mount_point" || true
        check_disk_space "$mount_point" || true
        check_inodes "$mount_point" || true
    fi
done

# Odeslání alertu pokud je potřeba
if [ -s "$ALERT_FILE" ]; then
    ALERTS=$(cat "$ALERT_FILE")
    log "🚨 Odeslání alertu..."
    # TODO: Poslat notifikaci do Home Assistant
fi

log "---"
SCRIPT
    
    chmod +x "/usr/local/bin/storage-health-check.sh"
    log_success "Health check skript vytvořen"
    
    # Vytvoření systemd služby pro health check
    cat > "/etc/systemd/system/storage-health-check.service" <<SERVICE
[Unit]
Description=Storage Health Check Service
After=local-fs.target
Documentation=https://github.com/Fatalerorr69/rpi5-homeassistant-suite

[Service]
Type=oneshot
ExecStart=/usr/local/bin/storage-health-check.sh /mnt/*
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE
    
    # Vytvoření timeru
    cat > "/etc/systemd/system/storage-health-check.timer" <<TIMER
[Unit]
Description=Storage Health Check Timer
Documentation=https://github.com/Fatalerorr69/rpi5-homeassistant-suite

[Timer]
OnBootSec=5min
OnUnitActiveSec=15min
Persistent=true

[Install]
WantedBy=timers.target
TIMER
    
    log_success "Health check service a timer vytvořeny"
}

# ============================================================================
# AUTOMOUNT PROCEDURA
# ============================================================================

setup_auto_mount() {
    log_section "Nastavení Automatického Připojování"
    
    # Detekce zařízení z /etc/fstab
    log_info "Skenuji /etc/fstab..."
    
    local custom_mounts=$(grep -E "^UUID|^/dev/" /etc/fstab | grep -E "nofail|x-systemd" || true)
    
    if [ -z "$custom_mounts" ]; then
        log_warn "Žádné custom mount pointy v /etc/fstab"
        log_info "Přidejte disky pomocí: sudo blkid"
        return 1
    fi
    
    # Parsování fstab
    while IFS= read -r line; do
        # Přeskočit komentáře
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue
        
        # Extrakce parametrů
        local device=$(echo "$line" | awk '{print $1}')
        local mount_point=$(echo "$line" | awk '{print $2}')
        local fstype=$(echo "$line" | awk '{print $3}')
        
        log_info "Zpracovávám: $device -> $mount_point ($fstype)"
        
        # Vytvoření mount pointu
        mkdir -p "$mount_point"
        
        # Extrakce UUID
        if [[ "$device" == UUID=* ]]; then
            local uuid="${device#UUID=}"
            create_mount_unit "$uuid" "$mount_point" "$fstype"
        fi
    done <<< "$custom_mounts"
    
    log_success "Systemd jednotky vytvořeny"
}

# ============================================================================
# AKTIVACE A TESTY
# ============================================================================

activate_systemd_units() {
    log_section "Aktivace Systemd Jednotek"
    
    log_info "Reloaduji systemd daemon..."
    systemctl daemon-reload
    
    log_info "Aktivuji auto-mount jednotky..."
    for mount_unit in /etc/systemd/system/*.mount; do
        if [ -f "$mount_unit" ]; then
            local unit_name=$(basename "$mount_unit")
            log_info "Povoluju: $unit_name"
            systemctl enable "$unit_name"
        fi
    done
    
    log_info "Povoluju health check timer..."
    systemctl enable storage-health-check.timer
    systemctl start storage-health-check.timer
    
    log_success "Systemd jednotky aktivovány"
}

test_auto_mount() {
    log_section "Testování Automatického Připojování"
    
    # Vytvoření testovacího souboru
    log_info "Vytvářím test soubory..."
    
    for mount_point in /mnt/*; do
        if mountpoint -q "$mount_point" 2>/dev/null; then
            local test_file="$mount_point/.ha_automount_test_$(date +%s)"
            
            if touch "$test_file"; then
                log_success "Test zápisu OK: $mount_point"
                rm "$test_file"
            else
                log_error "Test zápisu selhal: $mount_point"
            fi
        fi
    done
    
    # Ověření mount pointů
    log_info "Připojené body:"
    df -h | grep /mnt | while read line; do
        log_info "  $line"
    done
}

# ============================================================================
# KONFIGURACE FSTAB
# ============================================================================

configure_fstab() {
    log_section "Konfigurace /etc/fstab"
    
    log_warn "POZOR: Měňte /etc/fstab pouze pokud víte co děláte!"
    
    # Backup
    cp /etc/fstab "/etc/fstab.backup.$(date +%Y%m%d_%H%M%S)"
    log_success "Backup /etc/fstab vytvořen"
    
    # Příklad: automatické připojování
    cat >> /etc/fstab <<'FSTAB'

# =========================================
# RPi5 Home Assistant - Auto Mount Config
# =========================================
# Odkomentujte a upravte podle vašich disků
#
# NVMe disk (tip: zjistit UUID: sudo blkid)
# UUID=XXXX-YYYY /mnt/nvme ext4 defaults,nofail,x-systemd.device-timeout=30 0 2
#
# SSD (SATA/USB)
# UUID=XXXX-YYYY /mnt/ssd ext4 defaults,nofail,x-systemd.device-timeout=30 0 2
#
# HDD
# UUID=XXXX-YYYY /mnt/hdd ext4 defaults,nofail,x-systemd.device-timeout=60 0 2
#
# NAS (SMB/CIFS)
# //192.168.1.100/backups /mnt/nas cifs credentials=/etc/samba/creds,iocharset=utf8,file_mode=0755,dir_mode=0755,nofail 0 0
#
# NAS (NFS)
# 192.168.1.100:/export/backups /mnt/nas_nfs nfs defaults,nofail,x-systemd.device-timeout=60 0 0
#

FSTAB
    
    log_success "/etc/fstab nakonfigurován"
    log_warn "DŮLEŽITÉ: Otevřete a upravte /etc/fstab podle vašich zařízení"
}

# ============================================================================
# DIAGNOSTIKA
# ============================================================================

show_diagnostics() {
    log_section "Diagnostika Úložišť"
    
    log_info "Dostupná zařízení:"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
    
    log_info ""
    log_info "UUID zařízení:"
    sudo blkid -o list
    
    log_info ""
    log_info "Připojené body:"
    df -h | grep /mnt
    
    log_info ""
    log_info "Systemd jednotky:"
    systemctl list-units --type mount,automount | grep /mnt || true
    
    log_info ""
    log_info "Systemd timery:"
    systemctl list-timers storage-health-check.timer || true
}

# ============================================================================
# HELP A INFO
# ============================================================================

show_help() {
    cat <<EOF
${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}
${CYAN}║                                                                ║${NC}
${CYAN}║   RPi5 Home Assistant - Auto Mount Storage                    ║${NC}
${CYAN}║                                                                ║${NC}
${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}

${GREEN}POUŽITÍ:${NC}
  sudo ./POST_INSTALL/setup_storage_auto_mount.sh [MOŽNOSTI]

${GREEN}MOŽNOSTI:${NC}
  --help              Zobrazit tuto nápovědu
  --diagnostics       Zobrazit diagnostiku
  --setup             Interaktivní nastavení (výchozí)

${GREEN}POSTUP:${NC}

  1. ${YELLOW}Identifikujte disky:${NC}
     sudo blkid

  2. ${YELLOW}Přidejte do /etc/fstab:${NC}
     # Příklad:
     UUID=abcd1234 /mnt/nvme ext4 defaults,nofail 0 2

  3. ${YELLOW}Spusťte nastavení:${NC}
     sudo ./POST_INSTALL/setup_storage_auto_mount.sh

  4. ${YELLOW}Ověřte:${NC}
     sudo mount -a
     df -h

${GREEN}SYSTEMD JEDNOTKY:${NC}

  Prohlížení:
    systemctl list-units --type mount,automount

  Ruční připojení:
    sudo systemctl start mnt-nvme.mount

  Vypnutí auto-mount:
    sudo systemctl disable mnt-nvme.mount

${GREEN}HEALTH CHECK:${NC}

  Nastavení:
    ${YELLOW}Spuští se automaticky každých 15 minut${NC}

  Ruční spuštění:
    sudo /usr/local/bin/storage-health-check.sh /mnt/*

  Log soubor:
    tail -f /var/log/storage-health-check.log

${GREEN}TROUBLESHOOTING:${NC}

  Disk se nepřipojuje:
    sudo systemctl status mnt-nvme.mount
    sudo journalctl -u mnt-nvme.mount -n 50

  Zápis je pomalý:
    iostat -x 1 5  # Monitorujte I/O

  Kontrola prostoru:
    du -sh /mnt/* | sort -rh

${CYAN}DOKUMENTACE:${NC}
  https://github.com/Fatalerorr69/rpi5-homeassistant-suite

EOF
}

# ============================================================================
# HLAVNÍ PROGRAM
# ============================================================================

main() {
    check_sudo
    
    log_section "RPi5 Home Assistant - Storage Auto Mount Setup v2.4.0"
    log "Spuštěno: $(date)"
    log "Log file: $LOG_FILE"
    
    # Parsování argumentů
    local mode="${1:-setup}"
    
    case "$mode" in
        --help|-h)
            show_help
            ;;
        --diagnostics)
            show_diagnostics
            ;;
        --setup|setup)
            # Plná procedura
            configure_fstab
            create_health_check_service
            setup_auto_mount
            activate_systemd_units
            test_auto_mount
            show_diagnostics
            
            log_section "✅ NASTAVENÍ DOKONČENO"
            log ""
            log "Následující kroky:"
            log "1. Upravte /etc/fstab a přidejte vaše disky"
            log "2. Spusťte: sudo mount -a"
            log "3. Ověřte: df -h"
            log "4. Restartujte: sudo reboot"
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
    
    log "Skončeno: $(date)"
}

main "$@"
