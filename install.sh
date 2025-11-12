#!/bin/bash

# ==========================================
# 🏠 RPi5 HOME ASSISTANT - ZÁKLADNÍ INSTALACE
# ==========================================
# Instaluje základní závislosti pro Home Assistant
# Podporuje: Ubuntu, Debian, Armbian na RPi5
# Autor: Fatalerorr69
# Verze: 2.1 (vylepšená robustnost)
# ==========================================

set -euo pipefail  # Exit na chybu, undefined vars, pipe failure

# ============ GLOBÁLNÍ PROMĚNNÉ ============
readonly SCRIPT_VERSION="2.1"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="/home/$(whoami)/.homeassistant_install"
readonly LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"
readonly USER_NAME="${SUDO_USER:-$(whoami)}"
readonly OS_INFO="/etc/os-release"

# Detekce CPU architektury (RPi5 = aarch64)
readonly CPU_ARCH="$(uname -m)"

# Barvený output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'  # No Color

# Flags
SKIP_DOCKER=0
SKIP_COMPOSE=0
SKIP_AGENT=0
DRY_RUN=0
RETRY_COUNT=3
RETRY_DELAY=5

# ============ FUNKCE ============

# Inicializace logu
init_logging() {
    mkdir -p "$LOG_DIR"
    echo "=== Home Assistant Install Log ===" > "$LOG_FILE"
    echo "Spuštěno: $(date)" >> "$LOG_FILE"
    echo "Uživatel: $USER_NAME" >> "$LOG_FILE"
    echo "Architektura: $CPU_ARCH" >> "$LOG_FILE"
    echo "Script verze: $SCRIPT_VERSION" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

# Logování s barvami
log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp="[$(date +'%Y-%m-%d %H:%M:%S')]"
    
    case "$level" in
        info)
            echo -e "${BLUE}${timestamp}${NC} ℹ️  $message" | tee -a "$LOG_FILE"
            ;;
        success)
            echo -e "${GREEN}${timestamp}${NC} ✅ $message" | tee -a "$LOG_FILE"
            ;;
        warn)
            echo -e "${YELLOW}${timestamp}${NC} ⚠️  $message" | tee -a "$LOG_FILE"
            ;;
        error)
            echo -e "${RED}${timestamp}${NC} ❌ $message" | tee -a "$LOG_FILE"
            ;;
        *)
            echo -e "$timestamp $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

# Detekce OS
detect_os() {
    if [ ! -f "$OS_INFO" ]; then
        log error "Nelze detekovat OS: $OS_INFO neexistuje"
        return 1
    fi
    
    . "$OS_INFO"
    
    case "$ID" in
        ubuntu|debian|armbian)
            log success "Detekován OS: $PRETTY_NAME"
            return 0
            ;;
        *)
            log warn "Neznámý OS: $ID (pokračuji s Debian/Ubuntu předpoklady)"
            return 0
            ;;
    esac
}

# Kontrola root/sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        log warn "Vyžadováno sudo oprávnění — zkouším elevaci..."
        # Pokud jsme v dev kontejneru bez sudo, pokračuj s varováním
        if ! command -v sudo &>/dev/null; then
            log warn "sudo není dostupný — pokračuji bez elevace (dev mód)"
            return 0
        fi
        exec sudo bash "$0" "$@"
    fi
    log success "Sudo oprávnění: OK"
}

# Funkce s retry logikou
run_with_retry() {
    local cmd_name="$1"
    shift
    local max_attempts="$RETRY_COUNT"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log info "[$attempt/$max_attempts] $cmd_name..."
        if "$@"; then
            log success "$cmd_name OK"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log warn "$cmd_name selhalo, čekám ${RETRY_DELAY}s..."
            sleep "$RETRY_DELAY"
        fi
        attempt=$((attempt + 1))
    done
    
    log warn "$cmd_name: vypršel počet pokusů"
    return 1
}

# Kontrola příkazu
command_exists() {
    command -v "$1" &>/dev/null
}

# Instalace balíčku s retry
install_package() {
    local package="$1"
    
    if command_exists "$package"; then
        log success "$package: již nainstalován"
        return 0
    fi
    
    if run_with_retry "apt-get install $package" \
        sudo apt-get install -y "$package" 2>&1; then
        log success "Nainstalován: $package"
        return 0
    else
        log warn "$package: instalace selhala (pokračuji)"
        return 1
    fi
}

# Kontrola PyYAML
check_pyyaml() {
    if python3 -c "import yaml" 2>/dev/null; then
        log success "PyYAML: OK"
        return 0
    fi
    
    log warn "PyYAML chybí, instaluji..."
    
    if run_with_retry "apt-get install python3-yaml" \
        sudo apt-get install -y python3-yaml 2>&1; then
        log success "PyYAML nainstalován (apt)"
        return 0
    fi
    
    log warn "apt selhal, zkouším pip3..."
    if run_with_retry "pip3 install pyyaml" \
        sudo pip3 install pyyaml 2>&1; then
        log success "PyYAML nainstalován (pip)"
        return 0
    fi
    
    log warn "PyYAML instalace selhala — YAML validace nebude dostupná"
    return 1
}

# Instalace Dockeru
install_docker() {
    if [ "$SKIP_DOCKER" -eq 1 ]; then
        log warn "Docker: přeskočen (--skip-docker)"
        return 0
    fi
    
    if command_exists docker; then
        log success "Docker: již nainstalován ($(docker --version))"
        return 0
    fi
    
    log info "Instalace Dockeru..."
    
    if [ "$DRY_RUN" -eq 1 ]; then
        log info "[DRY-RUN] Stažení skriptu get-docker.sh"
        return 0
    fi
    
    if run_with_retry "curl get-docker.sh" \
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh; then
        if sudo sh /tmp/get-docker.sh 2>&1 | tee -a "$LOG_FILE"; then
            log success "Docker: nainstalován"
            sudo systemctl enable docker 2>/dev/null || true
            sudo systemctl start docker 2>/dev/null || true
            return 0
        fi
    fi
    
    log error "Docker: instalace selhala"
    return 1
}

# Instalace Docker Compose
install_docker_compose() {
    if [ "$SKIP_COMPOSE" -eq 1 ]; then
        log warn "Docker Compose: přeskočen (--skip-compose)"
        return 0
    fi
    
    # Zkontroluj obě varianty
    if command_exists docker-compose || docker compose version &>/dev/null; then
        local version
        if command_exists docker-compose; then
            version=$(docker-compose --version 2>/dev/null)
        else
            version=$(docker compose version 2>/dev/null)
        fi
        log success "Docker Compose: OK ($version)"
        return 0
    fi
    
    log info "Instalace Docker Compose..."
    
    if [ "$DRY_RUN" -eq 1 ]; then
        log info "[DRY-RUN] Instalace docker-compose-plugin přes apt"
        return 0
    fi
    
    if run_with_retry "apt-get install docker-compose-plugin" \
        sudo apt-get install -y docker-compose-plugin 2>&1; then
        log success "Docker Compose: nainstalován"
        return 0
    fi
    
    log warn "Docker Compose: instalace selhala (pokračuji)"
    return 1
}

# Instalace os-agent
install_os_agent() {
    if [ "$SKIP_AGENT" -eq 1 ]; then
        log warn "os-agent: přeskočen (--skip-agent)"
        return 0
    fi
    
    if dpkg -l 2>/dev/null | grep -q "^ii.*os-agent"; then
        log success "os-agent: již nainstalován"
        return 0
    fi
    
    log info "Instalace os-agent (volitelná)..."
    
    if [ "$DRY_RUN" -eq 1 ]; then
        log info "[DRY-RUN] Stažení os-agent pro $CPU_ARCH"
        return 0
    fi
    
    # Detekce správné verze pro architekturu
    local agent_url=""
    case "$CPU_ARCH" in
        aarch64)
            agent_url="https://github.com/home-assistant/os-agent/releases/download/1.6.0/os-agent_1.6.0_linux_aarch64.deb"
            ;;
        armv7l)
            agent_url="https://github.com/home-assistant/os-agent/releases/download/1.6.0/os-agent_1.6.0_linux_armv7.deb"
            ;;
        x86_64)
            agent_url="https://github.com/home-assistant/os-agent/releases/download/1.6.0/os-agent_1.6.0_linux_x86_64.deb"
            ;;
        *)
            log warn "os-agent: neznámá architektura: $CPU_ARCH"
            return 1
            ;;
    esac
    
    local tmp_deb="/tmp/os-agent_latest.deb"
    
    if run_with_retry "wget os-agent.deb" \
        wget -O "$tmp_deb" --timeout=30 "$agent_url" 2>&1; then
        if sudo dpkg -i "$tmp_deb" 2>&1 | tee -a "$LOG_FILE"; then
            sudo systemctl enable haos-agent 2>/dev/null || true
            sudo systemctl start haos-agent 2>/dev/null || true
            log success "os-agent: nainstalován"
            return 0
        fi
    fi
    
    log warn "os-agent: instalace selhala (pokračuji — není kritický)"
    return 1
}

# Hlavní instalační funkce
install_dependencies() {
    log info "════════════════════════════════════════════════════"
    log info "🚀 RPi5 HOME ASSISTANT - ZAHÁJENÍ INSTALACE"
    log info "════════════════════════════════════════════════════"
    
    # Detekce a kontrola
    detect_os || { log error "Nelze detekovat OS"; exit 1; }
    
    # Aktualizace repozitářů
    log info "Aktualizace repozitářů..."
    if [ "$DRY_RUN" -ne 1 ]; then
        if ! run_with_retry "apt-get update" \
            sudo apt-get update -y 2>&1; then
            log error "apt-get update selhalo"
            exit 1
        fi
    fi
    
    log info "Upgrade systému..."
    if [ "$DRY_RUN" -ne 1 ]; then
        sudo apt-get upgrade -y 2>&1 | tail -5 >> "$LOG_FILE"
    fi
    
    # Instalace kritických balíčků
    log info "Instalace kritických balíčků..."
    
    local critical_packages=(
        "curl" "wget" "git" "jq"
        "python3" "python3-pip" "python3-venv"
    )
    
    for pkg in "${critical_packages[@]}"; do
        if ! install_package "$pkg"; then
            log error "Kritický balík $pkg nelze nainstalovat"
            exit 1
        fi
    done
    
    # Instalace volitných balíčků
    log info "Instalace volitných balíčků..."
    
    local optional_packages=(
        "python3-dev" "build-essential"
        "libffi-dev" "libssl-dev"
        "tzdata" "lsb-release" "apt-transport-https"
        "ca-certificates" "gnupg2" "software-properties-common"
        "apparmor" "apparmor-utils"
        "dbus" "network-manager" "systemd-resolved"
        "rsync" "curl" "openssh-server"
    )
    
    for pkg in "${optional_packages[@]}"; do
        install_package "$pkg" || true
    done
    
    # Kontrola PyYAML
    check_pyyaml || true
    
    # Instalace Docker komponent
    log info "Instalace Docker komponent..."
    install_docker || true
    install_docker_compose || true
    
    # Přidání uživatele do skupin
    log info "Nastavení oprávnění..."
    if [ "$DRY_RUN" -ne 1 ]; then
        sudo usermod -aG docker "$USER_NAME" 2>/dev/null || \
            log warn "Přidání do docker skupiny selhalo"
        sudo usermod -aG dialout "$USER_NAME" 2>/dev/null || \
            log warn "Přidání do dialout skupiny selhalo"
        sudo usermod -aG tty "$USER_NAME" 2>/dev/null || \
            log warn "Přidání do tty skupiny selhalo"
    fi
    
    # Nastavení služeb
    log info "Nastavení systémových služeb..."
    if [ "$DRY_RUN" -ne 1 ]; then
        sudo systemctl enable systemd-resolved 2>/dev/null || true
        sudo systemctl start systemd-resolved 2>/dev/null || true
        sudo systemctl enable docker 2>/dev/null || true
        sudo systemctl start docker 2>/dev/null || true
    fi
    
    # Nastavení časového pásma
    log info "Nastavení časového pásma..."
    if [ "$DRY_RUN" -ne 1 ]; then
        sudo timedatectl set-timezone Europe/Prague 2>/dev/null || \
            log warn "Nastavení časového pásma selhalo"
    fi
    
    # Vytvoření adresářové struktury
    log info "Vytváření adresářové struktury..."
    if [ "$DRY_RUN" -ne 1 ]; then
        mkdir -p ~/homeassistant
        mkdir -p ~/rpi5-homeassistant-suite/config/{mosquitto,zigbee2mqtt,node-red,portainer}
        mkdir -p ~/backups
    fi
    
    # os-agent (volitelný)
    install_os_agent || true
    
    # Finální zpráva
    log success "════════════════════════════════════════════════════"
    log success "✅ INSTALACE ZÁVISLOSTÍ DOKONČENA"
    log success "════════════════════════════════════════════════════"
    log info "📋 Log uložen do: $LOG_FILE"
    log info "👤 Uživatel: $USER_NAME"
    log info "🏗️  Architektura: $CPU_ARCH"
    log info ""
    log info "Dalši kroky:"
    log info "  1. Odhlašte se a znovu se přihlašte (pro platnost skupin)"
    log info "  2. Spusťte: ./setup_master.sh"
    log info ""
}

# Zobrazení nápovědy
show_help() {
    cat <<EOF
RPi5 Home Assistant - Instalace závislostí
Verze: $SCRIPT_VERSION

Použití: $0 [VOLBY] [PŘÍKAZ]

PŘÍKAZY:
  install      Instalace závislostí (výchozí)
  help         Zobrazení nápovědy
  check        Pouze kontrola, bez instalace

VOLBY:
  --skip-docker      Přeskočit instalaci Dockeru
  --skip-compose     Přeskočit instalaci Docker Compose
  --skip-agent       Přeskočit instalaci os-agent
  --dry-run          Simulace bez skutečných změn
  --retry N          Počet pokusů (výchozí: $RETRY_COUNT)
  -h, --help         Zobrazit tuto nápovědu

PŘÍKLADY:
  $0 install                    # Standardní instalace
  $0 --dry-run install          # Simulace
  $0 --skip-docker install      # Bez Dockeru
  $0 check                       # Pouze kontrola
  $0 help                        # Nápověda

EOF
}

# ============ MAIN ============

# Parsování argumentů
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-docker)
                SKIP_DOCKER=1
                shift
                ;;
            --skip-compose)
                SKIP_COMPOSE=1
                shift
                ;;
            --skip-agent)
                SKIP_AGENT=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                log warn "DRY-RUN MODE: žádné skutečné změny"
                shift
                ;;
            --retry)
                RETRY_COUNT="${2:-3}"
                shift 2
                ;;
            -h|--help|help)
                show_help
                exit 0
                ;;
            install|check)
                local action="$1"
                shift
                
                # Inicializace
                init_logging
                check_sudo
                
                # Spuštění
                if [ "$action" = "install" ]; then
                    install_dependencies
                elif [ "$action" = "check" ]; then
                    log info "Kontrola instalace..."
                    check_sudo || true
                    detect_os || true
                    # Zde je možno přidat další kontroly
                fi
                
                exit 0
                ;;
            *)
                log error "Neznámá volba: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Chyba: příliš málo argumentů
if [ $# -eq 0 ]; then
    init_logging
    check_sudo
    install_dependencies
else
    parse_args "$@"
fi
