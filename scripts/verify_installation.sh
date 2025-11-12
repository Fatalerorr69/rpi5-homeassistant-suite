#!/bin/bash
#
# RPi5 Home Assistant Configuration Verification Script
# Ověří integritu konfigurace a připravenost k nasazení
#

set -uo pipefail  # Bez -e, aby se script nezastavil na chybě

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPO_ROOT/verification_report_$TIMESTAMP.txt"

# Barvy
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Statistiky
PASSED=0
FAILED=0
WARNINGS=0

log() {
    echo -e "$1" | tee -a "$REPORT_FILE"
}

log_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1" | tee -a "$REPORT_FILE"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1" | tee -a "$REPORT_FILE"
    ((FAILED++))
}

log_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1" | tee -a "$REPORT_FILE"
    ((WARNINGS++))
}

log_header() {
    echo -e "\n${BLUE}╔══════════════════════════════════════════╗${NC}" | tee -a "$REPORT_FILE"
    echo -e "${BLUE}║ $1" | tee -a "$REPORT_FILE"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}\n" | tee -a "$REPORT_FILE"
}

# ============================================================================
# MAIN VERIFICATION
# ============================================================================

log_header "RPi5 Home Assistant Configuration Verification"

echo "Report: $REPORT_FILE" | tee -a "$REPORT_FILE"
echo "Time: $(date)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# 1. Ověřit existenci klíčových adresářů
log_header "1. Ověření adresářové struktury"

for dir in CONFIG config config_backup_* scripts .github docs; do
    if [ -d "$REPO_ROOT/$dir" ]; then
        log_pass "Adresář existuje: $dir"
    elif [[ "$dir" == "config_backup_"* ]]; then
        log_warn "Backup adresář neexistuje (je to OK): $dir"
    else
        log_fail "Adresář chybí: $dir"
    fi
done

# 2. Ověřit existenci klíčových souborů
log_header "2. Ověření klíčových souborů"

critical_files=(
    "install.sh"
    "setup_master.sh"
    "docker-compose.yml"
    "CONFIG/configuration.yaml"
    "config/configuration.yaml"
    "scripts/validate_ha_config.py"
    "scripts/merge_configs.sh"
    "docs/CONFIGURATION_MANAGEMENT.md"
)

for file in "${critical_files[@]}"; do
    if [ -f "$REPO_ROOT/$file" ]; then
        log_pass "Soubor existuje: $file"
    else
        log_fail "Soubor chybí: $file"
    fi
done

# 3. YAML validace
log_header "3. YAML validace"

yaml_files=(
    "CONFIG/configuration.yaml"
    "config/configuration.yaml"
    "docker-compose.yml"
)

if command -v python3 &>/dev/null; then
    for yaml_file in "${yaml_files[@]}"; do
        file_path="$REPO_ROOT/$yaml_file"
        if [ -f "$file_path" ]; then
            if python3 "$REPO_ROOT/scripts/validate_ha_config.py" "$file_path" >/dev/null 2>&1; then
                log_pass "YAML validní: $yaml_file"
            else
                error_msg=$(python3 "$REPO_ROOT/scripts/validate_ha_config.py" "$file_path" 2>&1 | head -1)
                log_fail "YAML chyba v $yaml_file: $error_msg"
            fi
        fi
    done
else
    log_warn "Python3 není dostupný pro YAML validaci"
fi

# 4. Bash syntax check
log_header "4. Bash skriptů syntaxe"

bash_files=(
    "install.sh"
    "setup_master.sh"
    "scripts/merge_configs.sh"
)

if command -v bash &>/dev/null; then
    for bash_file in "${bash_files[@]}"; do
        file_path="$REPO_ROOT/$bash_file"
        if [ -f "$file_path" ]; then
            if bash -n "$file_path" 2>/dev/null; then
                log_pass "Bash syntax OK: $bash_file"
            else
                error_msg=$(bash -n "$file_path" 2>&1 | head -1)
                log_fail "Bash syntax chyba v $bash_file: $error_msg"
            fi
        fi
    done
else
    log_warn "Bash není dostupný pro syntax check"
fi

# 5. Ověřit Docker spustitelné příkazy
log_header "5. Docker a Docker Compose"

if command -v docker &>/dev/null; then
    log_pass "Docker je nainstalován: $(docker --version)"
else
    log_fail "Docker není nainstalován"
fi

if command -v docker-compose &>/dev/null; then
    log_pass "Docker Compose je nainstalován: $(docker-compose --version)"
else
    log_fail "Docker Compose není nainstalován"
fi

# 6. Kontrola git statusu
log_header "6. Git status"

cd "$REPO_ROOT"

if git rev-parse --git-dir >/dev/null 2>&1; then
    log_pass "Git repository inicializováno"
    
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    log_pass "Aktuální branch: $current_branch"
    
    latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "none")
    log_pass "Poslední tag: $latest_tag"
    
    uncommitted=$(git status --porcelain | wc -l)
    if [ "$uncommitted" -eq 0 ]; then
        log_pass "Všechny změny jsou commitnuté"
    else
        log_warn "Máte $uncommitted necommitnutých změn"
    fi
else
    log_fail "Git repository není inicializováno"
fi

# 7. Ověřit permise
log_header "7. Oprávnění souborů"

if [ -x "$REPO_ROOT/install.sh" ]; then
    log_pass "install.sh je spustitelný"
else
    log_warn "install.sh není spustitelný (chmod +x)"
fi

if [ -x "$REPO_ROOT/setup_master.sh" ]; then
    log_pass "setup_master.sh je spustitelný"
else
    log_warn "setup_master.sh není spustitelný (chmod +x)"
fi

if [ -x "$REPO_ROOT/scripts/merge_configs.sh" ]; then
    log_pass "merge_configs.sh je spustitelný"
else
    log_warn "merge_configs.sh není spustitelný (chmod +x)"
fi

# 8. Kontrola konfigurace synchronizace
log_header "8. Konfigurace synchronizace"

if diff -q "$REPO_ROOT/CONFIG/configuration.yaml" "$REPO_ROOT/config/configuration.yaml" >/dev/null 2>&1; then
    log_pass "CONFIG/configuration.yaml a config/configuration.yaml jsou identické"
else
    log_fail "CONFIG/configuration.yaml a config/configuration.yaml se liší!"
    log "Spusťte: ./scripts/merge_configs.sh"
fi

# 9. Ověřit Home Assistant docker-compose
log_header "9. Docker Compose konfigurace"

if [ -f "$REPO_ROOT/docker-compose.yml" ]; then
    if grep -q "homeassistant:" "$REPO_ROOT/docker-compose.yml"; then
        log_pass "docker-compose.yml obsahuje homeassistant service"
    else
        log_fail "docker-compose.yml neobsahuje homeassistant service"
    fi
    
    if grep -q "./config:/config" "$REPO_ROOT/docker-compose.yml"; then
        log_pass "docker-compose.yml má správný config mount"
    else
        log_fail "docker-compose.yml nemá správný config mount"
    fi
fi

# 10. Systemové požadavky
log_header "10. Systémové požadavky"

if command -v python3 &>/dev/null; then
    python_version=$(python3 --version 2>&1 | awk '{print $2}')
    log_pass "Python3 je dostupný: $python_version"
else
    log_fail "Python3 není dostupný"
fi

if command -v git &>/dev/null; then
    git_version=$(git --version | awk '{print $3}')
    log_pass "Git je dostupný: $git_version"
else
    log_fail "Git není dostupný"
fi

# ============================================================================
# SOUHRN
# ============================================================================

log_header "Souhrn verifikace"

log "Prošlo:      ${GREEN}$PASSED${NC}"
log "Selhalo:     ${RED}$FAILED${NC}"
log "Varování:    ${YELLOW}$WARNINGS${NC}"

echo "" | tee -a "$REPORT_FILE"

if [ "$FAILED" -eq 0 ]; then
    log "${GREEN}✅ VERIFIKACE ÚSPĚŠNÁ${NC}"
    echo "" | tee -a "$REPORT_FILE"
    log "Systém je připraven pro instalaci Home Assistant!"
    log "Příští kroky:"
    log "  1. ./install.sh install"
    log "  2. ./setup_master.sh"
    exit 0
else
    log "${RED}❌ VERIFIKACE SELHALA${NC}"
    echo "" | tee -a "$REPORT_FILE"
    log "Prosím opravte chyby výše a spusťte znovu."
    exit 1
fi
