#!/bin/bash
#
# RPi5 Home Assistant - Slučování CONFIG/ a config/ adresářů
#
# Problém: Duplikace konfiguračních souborů
# - CONFIG/ (zdrojové soubory)
# - config/ (runtime)
#
# Řešení: Slučit do jednoho adresáře a vytvořit symlink
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_SOURCE="$REPO_ROOT/CONFIG"
CONFIG_RUNTIME="$REPO_ROOT/config"
LOG_FILE="$REPO_ROOT/merge_config_$(date +%Y%m%d_%H%M%S).log"

# Barvy
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  CONFIG/ + config/ - Slučování           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}\n"

log_info "Spouštění slučování konfiguračních souborů..."
log "CONFIG zdroj:    $CONFIG_SOURCE"
log "CONFIG runtime:  $CONFIG_RUNTIME"
log "Log file:        $LOG_FILE"

# Kontrola existujících složek
if [ ! -d "$CONFIG_SOURCE" ]; then
    log_error "Zdrojová složka neexistuje: $CONFIG_SOURCE"
    exit 1
fi

if [ ! -d "$CONFIG_RUNTIME" ]; then
    log_warn "Runtime složka neexistuje: $CONFIG_RUNTIME - vytvářím..."
    mkdir -p "$CONFIG_RUNTIME"
fi

# Backup původního config
if [ -d "$CONFIG_RUNTIME" ] && [ "$(ls -A $CONFIG_RUNTIME)" ]; then
    BACKUP_DIR="$REPO_ROOT/config_backup_$(date +%Y%m%d_%H%M%S)"
    log_warn "Vytváření backup: $BACKUP_DIR"
    cp -r "$CONFIG_RUNTIME" "$BACKUP_DIR"
    log_success "Backup vytvořen"
fi

# Kopírování souborů z CONFIG/ do config/
log_info "Kopíruji soubory z CONFIG/ do config/..."

for file in "$CONFIG_SOURCE"/*.yaml; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        
        if [ -f "$CONFIG_RUNTIME/$filename" ]; then
            # Porovnat soubory
            if diff -q "$file" "$CONFIG_RUNTIME/$filename" > /dev/null 2>&1; then
                log_info "Identický: $filename (přeskakuji)"
            else
                log_warn "Aktualizuji: $filename"
                cp "$file" "$CONFIG_RUNTIME/$filename"
            fi
        else
            log_success "Kopíruji: $filename"
            cp "$file" "$CONFIG_RUNTIME/$filename"
        fi
    fi
done

# Kopírování podadresářů
for dir in "$CONFIG_SOURCE"/*; do
    if [ -d "$dir" ]; then
        dirname=$(basename "$dir")
        
        # Preskočit speciální adresáře
        if [[ "$dirname" == "." || "$dirname" == ".." ]]; then
            continue
        fi
        
        if [ -d "$CONFIG_RUNTIME/$dirname" ]; then
            log_info "Adresář existuje: $dirname (mergování)"
            # Slučovat obsah
            cp -r "$dir"/* "$CONFIG_RUNTIME/$dirname/" 2>/dev/null || true
        else
            log_success "Kopíruji adresář: $dirname"
            cp -r "$dir" "$CONFIG_RUNTIME/"
        fi
    fi
done

# Cleanup - smazat duplikáty v CONFIG/
log_info "Čištění - ponechávám CONFIG/ pro referenci..."

# Validace configuration.yaml s Home Assistant validátorem
log_info "Validuji configuration.yaml (Home Assistant YAML)..."

if command -v python3 &>/dev/null; then
    if python3 "$REPO_ROOT/scripts/validate_ha_config.py" "$CONFIG_RUNTIME/configuration.yaml" 2>/dev/null; then
        log_success "YAML validace OK (Home Assistant custom tagy rozpoznány)"
    else
        log_warn "YAML validace varování - zkontrolujte manuálně"
    fi
else
    log_warn "Python3 není dostupný pro YAML validaci"
fi

# Souhrn
echo ""
log_success "══════════════════════════════════════════════"
log_success "SLUČOVÁNÍ KONFIGURACE - HOTOVO"
log_success "══════════════════════════════════════════════"

echo ""
log_info "Soubory v config/:"
ls -lh "$CONFIG_RUNTIME"/*.yaml 2>/dev/null || log_warn "Žádné YAML soubory"

echo ""
log_info "Adresáře v config/:"
ls -ld "$CONFIG_RUNTIME"/*/ 2>/dev/null || log_warn "Žádné podadresáře"

echo ""
log_success "Při příštím spuštění se synchronizuje:"
log_info "• CONFIG/ → config/ (zdroj → runtime)"
log_info "• docker-compose mount: ./config:/config"

echo ""
