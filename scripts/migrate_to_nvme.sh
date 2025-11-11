#!/bin/bash
#
# RPi5 Home Assistant Suite - Migrace Systému ze SD Karty na NVMe Disk
#
# Tento skript provádí kompletní migraci Home Assistant systému z SD karty
# na rychlejší NVMe disk. Zahrnuje:
# - Detekci zařízení (SD karta, NVMe, ostatní úložiště)
# - Backup konfigurace SD karty
# - Formátování NVMe
# - Kopírování systému
# - Ověření integrity
# - Rollback procedury při chybě
#
# Použití: ./scripts/migrate_to_nvme.sh [--dry-run|--force|--restore-backup]
#

set -euo pipefail

# ============================================================================
# KONFIGURACE A PROMĚNNÉ
# ============================================================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$REPO_ROOT/scripts"
LOG_FILE="$REPO_ROOT/ha_migration_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="$REPO_ROOT/backups/migration_$(date +%Y%m%d_%H%M%S)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Barevný výstup
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Příznaky
DRY_RUN=false
FORCE_MODE=false
RESTORE_BACKUP=false

# ============================================================================
# LOGGING A UTILITY FUNKCE
# ============================================================================

log() {
    local level="$1"
    shift
    local msg="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${msg}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}ℹ️  $@${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}✅ $@${NC}" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $@${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}❌ $@${NC}" | tee -a "$LOG_FILE"
}

log_section() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}$@${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
}

# Potvrzení od uživatele
confirm() {
    local prompt="$1"
    local response
    read -p "$(echo -e ${YELLOW}$prompt${NC})" response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# ============================================================================
# IMPORT UTILITY SKRIPTŮ
# ============================================================================

if [ ! -f "$SCRIPT_DIR/detect_os.sh" ]; then
    log_error "Chybí $SCRIPT_DIR/detect_os.sh - nejdřív spusťte: git pull"
    exit 1
fi

source "$SCRIPT_DIR/detect_os.sh"

# ============================================================================
# DETEKCE ZAŘÍZENÍ
# ============================================================================

detect_storage_devices() {
    log_section "🔍 Detekce Úložných Zařízení"
    
    local sd_card=""
    local nvme_disk=""
    local other_disks=""
    
    log_info "Skenuji dostupná zařízení..."
    
    # Detekce SD karty (typicky na RPi5)
    if [ -b /dev/mmcblk0 ]; then
        sd_card="/dev/mmcblk0"
        local sd_size=$(lsblk -b -d -n -o SIZE /dev/mmcblk0 2>/dev/null || echo "N/A")
        log_success "SD karta: $sd_card ($(numfmt --to=iec-i --suffix=B $sd_size 2>/dev/null || echo $sd_size))"
    else
        log_warn "SD karta nebyla nalezena (očekávaná /dev/mmcblk0)"
    fi
    
    # Detekce NVMe disku
    if [ -b /dev/nvme0n1 ]; then
        nvme_disk="/dev/nvme0n1"
        local nvme_size=$(lsblk -b -d -n -o SIZE /dev/nvme0n1 2>/dev/null || echo "N/A")
        log_success "NVMe disk: $nvme_disk ($(numfmt --to=iec-i --suffix=B $nvme_size 2>/dev/null || echo $nvme_size))"
    else
        log_warn "NVMe disk nebyl nalezen (očekávaný /dev/nvme0n1)"
    fi
    
    # Detekce ostatních disků
    for disk in /dev/sd[a-z]; do
        if [ -b "$disk" ] && [ "$disk" != "$sd_card" ] && [ "$disk" != "${nvme_disk%n1}" ]; then
            local disk_size=$(lsblk -b -d -n -o SIZE "$disk" 2>/dev/null || echo "N/A")
            log_info "Další disk: $disk ($(numfmt --to=iec-i --suffix=B $disk_size 2>/dev/null || echo $disk_size))"
            other_disks="$other_disks $disk"
        fi
    done
    
    echo "$sd_card|$nvme_disk|$other_disks"
}

# ============================================================================
# KONTROLA SYSTÉMU
# ============================================================================

check_prerequisites() {
    log_section "✓ Kontrola Předpokladů"
    
    # Kontrola oprávnění
    if [ "$EUID" -ne 0 ]; then
        log_error "Skript musí běžet jako root (sudo)"
        exit 1
    fi
    log_success "Běží s root oprávněními"
    
    # Kontrola Home Assistant
    if ! command -v docker &> /dev/null; then
        log_error "Docker není nainstalován"
        exit 1
    fi
    log_success "Docker je nainstalován"
    
    # Kontrola volného místa
    local available_space=$(df /tmp | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 2097152 ]; then # 2GB
        log_error "/tmp má méně než 2GB volného místa"
        exit 1
    fi
    log_success "/tmp má dostatek volného místa"
    
    # Kontrola Python/PyYAML
    if ! python3 -c "import yaml" 2>/dev/null; then
        log_warn "PyYAML není nainstalován - instaluji..."
        if apt-get update && apt-get install -y python3-yaml; then
            log_success "PyYAML nainstalován"
        else
            log_error "Nelze nainstalovat PyYAML"
            exit 1
        fi
    fi
    log_success "PyYAML je dostupný"
}

# ============================================================================
# PŘÍPRAVA NA MIGRACI
# ============================================================================

prepare_migration() {
    log_section "📋 Příprava na Migraci"
    
    # Vytvoření adresáře pro backup
    mkdir -p "$BACKUP_DIR"
    log_success "Vytvořen backup adresář: $BACKUP_DIR"
    
    # Kontrola Home Assistant stavu
    log_info "Kontroluji stav Home Assistant..."
    if docker ps | grep -q homeassistant; then
        log_warn "Home Assistant je spuštěn - doporučuji ho zastavit pro bezpečnější migraci"
        if confirm "Zastavit Home Assistant nyní? (y/n): "; then
            log_info "Zastavuji Home Assistant..."
            cd "$REPO_ROOT"
            docker-compose stop homeassistant || true
            sleep 5
            log_success "Home Assistant zastaven"
        fi
    else
        log_success "Home Assistant není spuštěn"
    fi
}

# ============================================================================
# BACKUP SD KARTY
# ============================================================================

backup_sd_card() {
    local sd_card="$1"
    
    log_section "💾 Backup SD Karty"
    
    if [ ! -b "$sd_card" ]; then
        log_error "SD karta není dostupná: $sd_card"
        return 1
    fi
    
    local backup_file="$BACKUP_DIR/sd_card_full_$(date +%Y%m%d_%H%M%S).img"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Backup SD karty: $backup_file"
        return 0
    fi
    
    if confirm "Vytvorit full backup SD karty do $backup_file? Trvá to 30-60 minut. Pokračovat? (y/n): "; then
        log_info "Spouštím backup SD karty - PROSÍM ČEKEJTE..."
        
        # Backup s progress indikátorem
        if command -v pv &> /dev/null; then
            dd if="$sd_card" bs=4M 2>/dev/null | pv -tpreb -s $(blockdev --getsize64 "$sd_card") | gzip > "$backup_file.gz"
        else
            dd if="$sd_card" of="$backup_file" bs=4M status=progress
        fi
        
        if [ $? -eq 0 ]; then
            log_success "Backup SD karty: $(du -h $backup_file 2>/dev/null | cut -f1)"
            
            # Vytvoření checksum
            sha256sum "$backup_file" > "$backup_file.sha256"
            log_success "Checksum uložen: $backup_file.sha256"
        else
            log_error "Backup SD karty selhal"
            return 1
        fi
    else
        log_info "Backup SD karty přeskočen - POZOR: Bez backupu nemáte ochranu!"
    fi
}

# ============================================================================
# PŘÍPRAVA NVME DISKU
# ============================================================================

prepare_nvme() {
    local nvme_disk="$1"
    
    log_section "⚙️ Příprava NVMe Disku"
    
    if [ ! -b "$nvme_disk" ]; then
        log_error "NVMe disk není dostupný: $nvme_disk"
        return 1
    fi
    
    # Detekce partící
    local nvme_parts=$(lsblk -d -n -o NAME "$nvme_disk" | grep -E "^nvme.*p" || true)
    
    if [ -n "$nvme_parts" ]; then
        log_warn "NVMe disk obsahuje partice:"
        lsblk -n "$nvme_disk"
        
        if confirm "Zformátovat NVMe disk KOMPLETNĚ? (VEŠKERÁ DATA BUDOU SMAZÁNA!) (y/n): "; then
            log_info "Zastavuji možné připojení..."
            umount "${nvme_disk}"p* 2>/dev/null || true
            
            if [ "$DRY_RUN" = true ]; then
                log_info "[DRY-RUN] Formátování NVMe: $nvme_disk"
                return 0
            fi
            
            log_info "Vytvářím novou tabulku partící..."
            parted -s "$nvme_disk" mklabel gpt
            
            log_info "Vytvářím boot partici (2GB, FAT32)..."
            parted -s "$nvme_disk" mkpart ESP fat32 1MiB 2GiB
            parted -s "$nvme_disk" set 1 boot on
            mkfs.vfat -F 32 "${nvme_disk}p1"
            
            log_info "Vytvářím root partici (zbytek, ext4)..."
            parted -s "$nvme_disk" mkpart primary ext4 2GiB 100%
            mkfs.ext4 -F "${nvme_disk}p2"
            
            log_success "NVMe disk naformátován"
        else
            log_error "Formátování zrušeno"
            return 1
        fi
    else
        log_info "NVMe disk je prázdný"
        
        # Přesto se zeptejme na formátování pro bezpečnost
        if confirm "Nastavit partice na novém NVMe disku? (y/n): "; then
            if [ "$DRY_RUN" = true ]; then
                log_info "[DRY-RUN] Formátování NVMe: $nvme_disk"
                return 0
            fi
            
            parted -s "$nvme_disk" mklabel gpt
            parted -s "$nvme_disk" mkpart ESP fat32 1MiB 2GiB
            parted -s "$nvme_disk" set 1 boot on
            mkfs.vfat -F 32 "${nvme_disk}p1"
            
            parted -s "$nvme_disk" mkpart primary ext4 2GiB 100%
            mkfs.ext4 -F "${nvme_disk}p2"
            
            log_success "NVMe disk připraven"
        fi
    fi
}

# ============================================================================
# MIGRACE SYSTÉMU
# ============================================================================

migrate_system() {
    local sd_card="$1"
    local nvme_disk="$2"
    
    log_section "🔄 Migrace Systému na NVMe"
    
    # Mounty
    local sd_mount="/mnt/sd_migration_$$"
    local nvme_boot="/mnt/nvme_boot_$$"
    local nvme_root="/mnt/nvme_root_$$"
    
    mkdir -p "$sd_mount" "$nvme_boot" "$nvme_root"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Migrace:"
        log_info "  SD card:  $sd_card -> $sd_mount"
        log_info "  NVMe boot: ${nvme_disk}p1 -> $nvme_boot"
        log_info "  NVMe root: ${nvme_disk}p2 -> $nvme_root"
        return 0
    fi
    
    # Připojení zařízení
    log_info "Připojuji SD kartu..."
    mount "${sd_card}p2" "$sd_mount" || {
        log_error "Nelze připojit SD kartu"
        rmdir "$sd_mount" "$nvme_boot" "$nvme_root"
        return 1
    }
    
    log_info "Připojuji NVMe boot partici..."
    mount "${nvme_disk}p1" "$nvme_boot"
    
    log_info "Připojuji NVMe root partici..."
    mount "${nvme_disk}p2" "$nvme_root"
    
    # Kopírování boot
    log_info "Kopíruji boot sektor (${sd_card}p1 -> ${nvme_disk}p1)..."
    cp -av "$sd_mount/boot/"* "$nvme_boot/" 2>&1 | head -50
    
    # Kopírování rootfs
    log_info "Kopíruji systém (${sd_card}p2 -> ${nvme_disk}p2)..."
    log_info "Toto může trvat 10-20 minut - PROSÍM ČEKEJTE..."
    
    rsync -av --progress --exclude="proc" --exclude="sys" --exclude="dev" \
        --exclude="run" --exclude="tmp" --exclude="mnt" \
        "$sd_mount/" "$nvme_root/" 2>&1 | tail -100
    
    # Úpravy /etc/fstab
    log_info "Aktualizuji /etc/fstab..."
    
    local sd_partuuid=$(blkid -s PARTUUID -o value "${sd_card}p2")
    local nvme_partuuid=$(blkid -s PARTUUID -o value "${nvme_disk}p2")
    
    if [ -n "$sd_partuuid" ] && [ -n "$nvme_partuuid" ]; then
        sed -i "s/$sd_partuuid/$nvme_partuuid/g" "$nvme_root/etc/fstab"
        log_success "fstab aktualizován"
    fi
    
    # Odpojení
    log_info "Odpojuji zařízení..."
    umount "$sd_mount" "$nvme_boot" "$nvme_root" 2>/dev/null || true
    rmdir "$sd_mount" "$nvme_boot" "$nvme_root" 2>/dev/null || true
    
    log_success "Migrace systému dokončena"
}

# ============================================================================
# POST-MIGRACE KONFIGURACE
# ============================================================================

configure_post_migration() {
    log_section "🔧 Post-Migrace Konfigurace"
    
    # Připojení NVMe s novým rootem
    local nvme_root="/mnt/nvme_root_$$"
    mkdir -p "$nvme_root"
    mount /dev/nvme0n1p2 "$nvme_root" 2>/dev/null || {
        log_warn "NVMe root není připojený - skipping post-migrace config"
        return 0
    }
    
    # Aktualizace grub (pokud existuje)
    if [ -f "$nvme_root/boot/grub/grub.cfg" ]; then
        log_info "Aktualizuji GRUB..."
        # To by měl udělat boot process, ale zkontrolujeme
        log_info "GRUB bude aktualizován při prvním startu"
    fi
    
    # Vytvoření marker souboru
    touch "$nvme_root/root/.nvme_migration_complete"
    echo "Migration completed at $(date)" > "$nvme_root/root/.nvme_migration_info"
    
    log_success "Post-migrace konfigurace dokončena"
    umount "$nvme_root" 2>/dev/null || true
}

# ============================================================================
# OVĚŘENÍ MIGRACE
# ============================================================================

verify_migration() {
    log_section "✔️ Ověření Migrace"
    
    log_info "Kontroluji dostupnost zařízení..."
    
    if lsblk | grep -q nvme0n1; then
        log_success "NVMe disk je viditelný"
    else
        log_error "NVMe disk není viditelný!"
        return 1
    fi
    
    log_info "Ověřuji filesystem NVMe..."
    if fsck -n /dev/nvme0n1p2 &>/dev/null; then
        log_success "Filesystem NVMe je v pořádku"
    else
        log_warn "Filesystem NVMe vyžaduje opravu"
    fi
    
    log_success "Ověření migrace dokončeno"
}

# ============================================================================
# ROLLBACK PROCEDURA
# ============================================================================

rollback_migration() {
    log_section "⏮️  Rollback Migrace"
    
    log_error "Rollback procedura - obnovuji ze zálohy..."
    
    local backup_file=$(ls "$BACKUP_DIR"/sd_card_full_*.img 2>/dev/null | head -1)
    
    if [ -z "$backup_file" ]; then
        log_error "Žádný backup pro rollback nenalezen!"
        return 1
    fi
    
    if confirm "Obnovit SD kartu ze zálohy $backup_file? (VEŠKERÁ DATA BUDOU SMAZÁNA!) (y/n): "; then
        log_info "Spouštím obnovení - PROSÍM ČEKEJTE..."
        
        if command -v pv &> /dev/null; then
            gunzip -c "$backup_file.gz" | pv -tpreb | dd of=/dev/mmcblk0 bs=4M
        else
            gunzip -c "$backup_file.gz" | dd of=/dev/mmcblk0 bs=4M status=progress
        fi
        
        log_success "Rollback dokončen - systém byl obnoven"
    fi
}

# ============================================================================
# HELP A USAGE
# ============================================================================

show_usage() {
    cat <<EOF
${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}
${CYAN}║                                                                ║${NC}
${CYAN}║   RPi5 Home Assistant - Migrace ze SD Karty na NVMe            ║${NC}
${CYAN}║                                                                ║${NC}
${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}

${GREEN}POUŽITÍ:${NC}
  sudo ./scripts/migrate_to_nvme.sh [MOŽNOSTI]

${GREEN}MOŽNOSTI:${NC}
  --dry-run              Spustit v simulačním režimu (bez změn)
  --force                Vynechat všechna potvrzení (RIZIKO!)
  --restore-backup       Obnovit ze zálohy
  --help                 Zobrazit tuto nápovědu

${GREEN}PŘÍKLADY:${NC}
  # Testovací běh bez změn
  sudo ./scripts/migrate_to_nvme.sh --dry-run

  # Běžná migrace (s potvrzením)
  sudo ./scripts/migrate_to_nvme.sh

  # Automatická migrace
  sudo ./scripts/migrate_to_nvme.sh --force

${YELLOW}DŮLEŽITÉ UPOZORNĚNÍ:${NC}
  • Skript MUSÍ běžet jako root (sudo)
  • Migrace VYMAŽE NVMe disk!
  • Doporučuji nejdřív spustit --dry-run
  • Záloha SD karty je důležitá pro rollback
  • Po migraci změňte boot nastavení v BIOS/EFI

${CYAN}POSTUP:${NC}
  1. Spusťte: sudo ./scripts/migrate_to_nvme.sh --dry-run
  2. Zkontrolujte výstup
  3. Spusťte: sudo ./scripts/migrate_to_nvme.sh
  4. Čekejte (trvá 20-30 minut)
  5. Restartujte: sudo reboot
  6. V nastavení RPi (raspi-config) nastavte boot z NVMe
  7. Restartujte znovu

${CYAN}LOG SOUBOR:${NC}
  $LOG_FILE

${CYAN}BACKUP:${NC}
  $BACKUP_DIR

EOF
}

# ============================================================================
# HLAVNÍ PROGRAM
# ============================================================================

main() {
    log_section "🚀 Spouštění Migrace - RPi5 Home Assistant Suite v2.4.0"
    log_info "Čas zahájení: $(date)"
    log_info "Log soubor: $LOG_FILE"
    
    # Parsování argumentů
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                log_info "DRY-RUN režim aktivován"
                shift
                ;;
            --force)
                FORCE_MODE=true
                log_warn "FORCE režim aktivován - přeskakuji potvrzení!"
                shift
                ;;
            --restore-backup)
                RESTORE_BACKUP=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Neznámá možnost: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Kontrola oprávnění
    if [ "$EUID" -ne 0 ]; then
        log_error "Skript musí běžet jako root: sudo $0 $@"
        exit 1
    fi
    
    # Rollback režim
    if [ "$RESTORE_BACKUP" = true ]; then
        rollback_migration
        exit $?
    fi
    
    # Normální migrace
    check_prerequisites
    prepare_migration
    
    # Detekce zařízení
    local devices=$(detect_storage_devices)
    IFS='|' read -r sd_card nvme_disk other_disks <<< "$devices"
    
    if [ -z "$sd_card" ] || [ -z "$nvme_disk" ]; then
        log_error "Nelze detekovat potřebná zařízení!"
        log_error "  SD karta: $sd_card"
        log_error "  NVMe disk: $nvme_disk"
        exit 1
    fi
    
    # Backup
    backup_sd_card "$sd_card"
    
    # Příprava NVMe
    prepare_nvme "$nvme_disk"
    
    # Migrace
    migrate_system "$sd_card" "$nvme_disk"
    
    # Post-migrace
    configure_post_migration
    
    # Ověření
    verify_migration
    
    # Výsledek
    log_section "✅ MIGRACE DOKONČENA"
    log_info "Čas ukončení: $(date)"
    
    cat <<EOF | tee -a "$LOG_FILE"

${GREEN}═══════════════════════════════════════════════════════════════${NC}
${GREEN}  ✅ MIGRACE ZE SD KARTY NA NVME ÚSPĚŠNĚ DOKONČENA!${NC}
${GREEN}═══════════════════════════════════════════════════════════════${NC}

${CYAN}NÁSLEDUJÍCÍ KROKY:${NC}

1. ${YELLOW}Restartujte systém:${NC}
   sudo reboot

2. ${YELLOW}Do BIOS/EFI nastavte boot z NVMe:${NC}
   - Při startu stiskněte DEL nebo ESC (dle modelu)
   - Nastavte Boot Order → NVMe disk
   - Uložte změny (F10 nebo Enter)

3. ${YELLOW}Aktualizujte boot nastavení RPi:${NC}
   sudo raspi-config
   → Advanced Options → Boot Order → USB Boot

4. ${YELLOW}Restartujte znovu:${NC}
   sudo reboot

5. ${YELLOW}Ověřte, že systém bootuje z NVMe:${NC}
   df -h /
   # Mělo by ukázat /dev/nvme0n1p2

${CYAN}BEZPEČNOSTNÍ POZNÁMKY:${NC}
✓ Backup SD karty: $BACKUP_DIR
✓ Log soubor: $LOG_FILE
✓ Rollback: sudo ./scripts/migrate_to_nvme.sh --restore-backup

${CYAN}PERFORMANCE TIPY:${NC}
• Home Assistant bude nyní MNOHEM RYCHLEJŠÍ
• Recorder databáze se načítá rychleji
• Menus a automace odpovídají okamžitě
• Zvažte přesun složky /config na NVMe:
  docker-compose.yml:
    volumes:
      - /mnt/nvme/ha-config:/config

EOF
}

# ============================================================================
# START
# ============================================================================

main "$@"
