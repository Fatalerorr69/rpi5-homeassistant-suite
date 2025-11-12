#!/bin/bash
#
# Home Assistant Community Store (HACS) Installer
# Automatická instalace a správa HACS repozitářů a custom komponent
# 
# Použití:
#   ./scripts/install_hacs_repos.sh [--list|--install REPO|--install-all|--update]
#
# Příklady:
#   ./scripts/install_hacs_repos.sh --list              # Vypsat dostupné repozitáře
#   ./scripts/install_hacs_repos.sh --install mushroom  # Nainstalovat konkrétní repo
#   ./scripts/install_hacs_repos.sh --install-all       # Nainstalovat všechny recommended
#   ./scripts/install_hacs_repos.sh --update            # Aktualizovat všechny
#

set -euo pipefail

# ============================================================================
# KONFIGURACE
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HA_CONFIG_DIR="${PROJECT_ROOT}/config"
CUSTOM_COMPONENTS_DIR="${HA_CONFIG_DIR}/custom_components"
DOCKER_CONTAINER="rpi5-homeassistant-suite-homeassistant-1"

# Barvy pro výstup
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# HACS REPOZITÁŘE - DATABÁZE
# ============================================================================

declare -A REPOS=(
    # Frontend - UI komponenty
    ["mushroom"]="piitaya/lovelace-mushroom-cards|frontend|Krásné Material Design 3 karty"
    ["button-card"]="custom-cards/button-card|frontend|Flexibilní tlačítka s custom styly"
    ["mini-media"]="kalkih/mini-media-player|frontend|Mini přehrávač hudby"
    ["apexcharts"]="RomRider/apexcharts-card|frontend|Grafy a statistiky"
    ["monster-card"]="kalkih/monster-card|frontend|Dynamické karty podle podmínek"
    
    # Integraciones
    ["adaptive-light"]="basnijholt/adaptive-lighting|integration|Inteligentní osvětlení"
    ["local-tuya"]="rospogrigio/localtuya|integration|Lokální Tuya bez cloudu"
    ["browser-mod"]="thomasloven/hass-browser_mod|integration|Ovládání prohlížečů"
    ["simple-last-seen"]="kamaradclimber/simple-last-seen|integration|Sledování zařízení"
    ["presence-sim"]="slodki/Presence-Simulation|integration|Simulace přítomnosti"
    
    # System & Monitoring
    ["system-monitor"]="jcwillox/hass-system-monitor|integration|Monitoring CPU/RAM/disk"
    ["pi-hole"]="hassio-addons/pi-hole|addon|DNS a blokování reklam"
    ["ssh-terminal"]="jcwillox/hassio-ssh-terminal|addon|SSH přístup přes web"
    
    # Notifikace
    ["ntfy"]="jcwillox/hass-ntfy|integration|Push notifikace přes ntfy"
    ["telegram"]="rkoshak/sensorstalk-hass-addon|addon|Telegram notifikace"
    
    # Offline AI
    ["wyoming"]="rhasspy/wyoming|integration|Offline řeč zpracování"
    ["openwakeword"]="openwakword/openwakword|integration|Probuzení bez cloudu"
)

# ============================================================================
# FUNKCE
# ============================================================================

log() {
    local level="$1"
    local msg="$2"
    case "$level" in
        info)
            echo -e "${BLUE}[INFO]${NC} $msg"
            ;;
        success)
            echo -e "${GREEN}[✓]${NC} $msg"
            ;;
        warn)
            echo -e "${YELLOW}[!]${NC} $msg"
            ;;
        error)
            echo -e "${RED}[✗]${NC} $msg"
            ;;
        debug)
            if [[ "${VERBOSE:-0}" == "1" ]]; then
                echo -e "${CYAN}[DEBUG]${NC} $msg"
            fi
            ;;
    esac
}

show_help() {
    cat << EOF
${CYAN}Home Assistant HACS Repository Installer${NC}

Použití: $(basename "$0") [VOLBY]

Volby:
    --list                    Vypsat všechny dostupné repozitáře
    --install REPO            Nainstalovat konkrétní repozitář (jméno z --list)
    --install-all             Nainstalovat všechny doporučené (frontend + integrace)
    --install-essentials      Nainstalovat jen nejdůležitější (mushroom, local-tuya, system-monitor)
    --update                  Aktualizovat všechny nainstalované komponenty
    --check                   Ověřit stav instalace
    --remove REPO             Odinstalovat repozitář
    --docker                  Použít docker-compose příkazy (automatické)
    --verbose, -v             Detailní výstup
    --help, -h                Zobrazit tuto nápovědu

Příklady:
    $(basename "$0") --list
    $(basename "$0") --install mushroom
    $(basename "$0") --install-all
    $(basename "$0") --install-essentials
    $(basename "$0") --update --verbose

Repozitáře:
EOF
    
    for repo in "${!REPOS[@]}"; do
        IFS='|' read -r url category desc <<< "${REPOS[$repo]}"
        printf "    %-20s [%-12s] %s\n" "$repo" "$category" "$desc"
    done | sort
}

list_repos() {
    log info "Dostupné HACS repozitáře:"
    echo ""
    
    echo -e "${CYAN}=== FRONTEND (Karty a UI) ===${NC}"
    for repo in mushroom button-card mini-media apexcharts monster-card; do
        IFS='|' read -r url category desc <<< "${REPOS[$repo]}"
        printf "  %-20s %s\n" "• $repo" "$desc"
    done
    
    echo ""
    echo -e "${CYAN}=== INTEGRACIONES ===${NC}"
    for repo in adaptive-light local-tuya browser-mod simple-last-seen presence-sim; do
        IFS='|' read -r url category desc <<< "${REPOS[$repo]}"
        printf "  %-20s %s\n" "• $repo" "$desc"
    done
    
    echo ""
    echo -e "${CYAN}=== MONITORING & SYSTÉM ===${NC}"
    for repo in system-monitor pi-hole ssh-terminal; do
        IFS='|' read -r url category desc <<< "${REPOS[$repo]}"
        printf "  %-20s %s\n" "• $repo" "$desc"
    done
    
    echo ""
    echo -e "${CYAN}=== NOTIFIKACE ===${NC}"
    for repo in ntfy telegram; do
        IFS='|' read -r url category desc <<< "${REPOS[$repo]}"
        printf "  %-20s %s\n" "• $repo" "$desc"
    done
    
    echo ""
    echo -e "${CYAN}=== OFFLINE AI ===${NC}"
    for repo in wyoming openwakeword; do
        IFS='|' read -r url category desc <<< "${REPOS[$repo]}"
        printf "  %-20s %s\n" "• $repo" "$desc"
    done
}

check_docker() {
    if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
        log error "docker-compose nebo docker není nainstalován"
        return 1
    fi
    
    if ! docker ps &> /dev/null; then
        log error "Docker daemon není spuštěn"
        return 1
    fi
    
    return 0
}

check_container() {
    if ! docker-compose -f "$PROJECT_ROOT/docker-compose.yml" ps homeassistant 2>/dev/null | grep -q "Up"; then
        log error "Home Assistant kontejner není spuštěný"
        log info "Spusťte: cd $PROJECT_ROOT && docker-compose up -d"
        return 1
    fi
    return 0
}

install_hacs() {
    log info "Instalace HACS do Home Assistant..."
    
    if ! check_docker; then
        log error "Docker kontrola selhala"
        return 1
    fi
    
    if ! check_container; then
        log error "Home Assistant není dostupný"
        return 1
    fi
    
    # Stažení HACS
    local hacs_url="https://github.com/hacs/integration/releases/download/1.33.0/hacs.zip"
    local hacs_dir="$CUSTOM_COMPONENTS_DIR/hacs"
    
    log info "Stažení HACS z GitHub..."
    mkdir -p "$CUSTOM_COMPONENTS_DIR"
    cd "$CUSTOM_COMPONENTS_DIR"
    
    if wget -q "$hacs_url" -O hacs.zip 2>/dev/null; then
        log success "HACS stažen"
        unzip -q hacs.zip -d hacs
        rm hacs.zip
        log success "HACS extrahován"
    else
        log error "Selhalo stažení HACS"
        return 1
    fi
    
    # Restart Home Assistant
    log info "Restart Home Assistant..."
    docker-compose -f "$PROJECT_ROOT/docker-compose.yml" restart homeassistant
    
    sleep 10
    log success "HACS by měl být nyní dostupný"
    log info "Jděte do Home Assistant UI: Settings → Devices & Services → HACS"
}

install_repository() {
    local repo_key="$1"
    
    if [[ -z "${REPOS[$repo_key]:-}" ]]; then
        log error "Repozitář '$repo_key' nebyl nalezen"
        return 1
    fi
    
    IFS='|' read -r url category desc <<< "${REPOS[$repo_key]}"
    
    log info "Instalace: $repo_key"
    log info "  URL: https://github.com/$url"
    log info "  Typ: $category"
    log info "  Popis: $desc"
    
    case "$category" in
        frontend)
            log info "Frontend karta se musí přidat ručně v HACS UI"
            log info "  Settings → Devices & Services → HACS"
            log info "  → Frontend → $desc"
            ;;
        integration)
            log info "Integrace se musí přidat ručně v HACS UI"
            log info "  Settings → Devices & Services → HACS"
            log info "  → Integrations → $desc"
            ;;
        addon)
            log info "Add-on se musí přidat ručně v Home Assistant Add-on Store"
            log info "  Settings → Add-ons & Backups → Add-on Store"
            log info "  → Vyhledej: $desc"
            ;;
    esac
    
    log success "Repozitář $repo_key je připraven k instalaci"
}

install_all() {
    log info "Instalace všech doporučených repozitářů..."
    
    # Essential
    local essential=(mushroom local-tuya system-monitor adaptive-light)
    
    # Recommended
    local recommended=(button-card apexcharts browser-mod simple-last-seen)
    
    log info "Instalace Essential repozitářů:"
    for repo in "${essential[@]}"; do
        install_repository "$repo"
    done
    
    echo ""
    log info "Instalace Recommended repozitářů:"
    for repo in "${recommended[@]}"; do
        install_repository "$repo"
    done
    
    echo ""
    log success "Všechny repozitáře jsou připraveny"
    log info "Návštivte Home Assistant UI pro jejich instalaci"
}

install_essentials() {
    log info "Instalace Essential repozitářů..."
    
    local essential=(mushroom local-tuya system-monitor)
    
    for repo in "${essential[@]}"; do
        install_repository "$repo"
    done
    
    log success "Essential repozitáře jsou připraveny"
}

check_installation() {
    log info "Kontrola stavu HACS instalace..."
    
    # Check HACS
    if [[ -d "$CUSTOM_COMPONENTS_DIR/hacs" ]]; then
        log success "HACS je instalován"
    else
        log warn "HACS není nalezen v $CUSTOM_COMPONENTS_DIR/hacs"
    fi
    
    # List installed custom components
    if [[ -d "$CUSTOM_COMPONENTS_DIR" ]]; then
        log info "Nainstalované custom komponenty:"
        for comp in "$CUSTOM_COMPONENTS_DIR"/*; do
            if [[ -d "$comp" ]]; then
                echo "  • $(basename "$comp")"
            fi
        done
    else
        log warn "Adresář custom_components neexistuje"
    fi
}

remove_repository() {
    local repo_key="$1"
    local comp_dir="$CUSTOM_COMPONENTS_DIR/$repo_key"
    
    if [[ ! -d "$comp_dir" ]]; then
        log warn "Komponenta '$repo_key' není nainstalována"
        return 1
    fi
    
    log warn "Odebírání: $repo_key"
    read -p "Opravdu chcete odstranit $repo_key? (ano/ne) " confirm
    
    if [[ "$confirm" == "ano" ]]; then
        rm -rf "$comp_dir"
        log success "Komponenta $repo_key odstraněna"
        log info "Restartujte Home Assistant pro aplikaci změn"
    else
        log info "Zrušeno"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local action="${1:-}"
    
    case "$action" in
        --help|-h)
            show_help
            ;;
        --list)
            list_repos
            ;;
        --install)
            if [[ -z "${2:-}" ]]; then
                log error "Prosím zadejte jméno repozitáře"
                show_help
                exit 1
            fi
            install_repository "$2"
            ;;
        --install-all)
            install_all
            ;;
        --install-essentials)
            install_essentials
            ;;
        --remove)
            if [[ -z "${2:-}" ]]; then
                log error "Prosím zadejte jméno komponenty"
                exit 1
            fi
            remove_repository "$2"
            ;;
        --check)
            check_installation
            ;;
        --update)
            log info "Aktualizace se provádí automaticky v HACS UI"
            log info "Settings → Devices & Services → HACS → Updates"
            ;;
        --verbose|-v)
            VERBOSE=1
            main "${2:-}"
            ;;
        *)
            if [[ -z "$action" ]]; then
                log info "Vítejte v HACS Installer!"
                log info "Spusťte '$(basename "$0") --help' pro nápovědu"
                log info ""
                list_repos
            else
                log error "Neznámá volba: $action"
                show_help
                exit 1
            fi
            ;;
    esac
}

main "$@"
