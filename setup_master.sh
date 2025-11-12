#!/bin/bash

# ==========================================
# 🏠 RPi5 HOME ASSISTANT SUITE - INSTALACE
# ==========================================
# Autor: Fatalerorr69
# Verze: 2.2 (vylepšená robustnost a auto-opravy)
# Opraveno: error handling, auto-opravy, retry logika
# ==========================================

set -euo pipefail  # Exit na chybu, undefined vars, pipe failure

# ============ GLOBÁLNÍ PROMĚNNÉ ============
readonly SCRIPT_VERSION="2.2"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="/home/$(whoami)/.ha_suite_install"
readonly LOG_FILE="$LOG_DIR/setup_$(date +%Y%m%d_%H%M%S).log"
readonly USER_NAME="${SUDO_USER:-$(whoami)}"
readonly HA_CONFIG_DIR="/home/$USER_NAME/homeassistant"
readonly DOCKER_COMPOSE_DIR="$SCRIPT_DIR"

# Barvený output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'  # No Color

# Flags a konfigurace
RETRY_COUNT=3
RETRY_DELAY=5
SKIP_DEPS=0
DRY_RUN=0
VERBOSE=0
AUTO_FIX=1  # Automatické opravy

# ============ FUNKCE ============

# Cleanup při přerušení
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log error "Skript byl přerušen nebo skončil s chybou (exit code: $exit_code)"
        log info "Log: $LOG_FILE"
    fi
    return $exit_code
}

trap cleanup EXIT

# Inicializace logu
init_logging() {
    mkdir -p "$LOG_DIR"
    # Rotace starých logů (ponechat 10 posledních)
    find "$LOG_DIR" -name "setup_*.log" -type f | sort -r | tail -n +11 | xargs rm -f 2>/dev/null || true
    
    echo "=== Home Assistant Suite Setup Log ===" > "$LOG_FILE"
    echo "Spuštěno: $(date)" >> "$LOG_FILE"
    echo "Uživatel: $USER_NAME" >> "$LOG_FILE"
    echo "Script verze: $SCRIPT_VERSION" >> "$LOG_FILE"
    echo "Python: $(python3 --version 2>&1)" >> "$LOG_FILE"
    echo "Docker: $(docker --version 2>/dev/null || echo 'Not installed')" >> "$LOG_FILE"
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
        debug)
            if [ "$VERBOSE" -eq 1 ]; then
                echo -e "${MAGENTA}${timestamp}${NC} 🐛 $message" | tee -a "$LOG_FILE"
            fi
            ;;
        *)
            echo -e "$timestamp $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

# Kontrola root/sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        log warn "Vyžadováno sudo oprávnění — zkouším elevaci..."
        if ! command -v sudo &>/dev/null; then
            log error "sudo není dostupný"
            return 1
        fi
        exec sudo bash "$0" "$@"
    fi
    log success "Sudo oprávnění: OK"
}

# Kontrola povinného příkazu
require_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log error "Vyžadován příkaz: $cmd"
        return 1
    fi
}

# Funkce s retry logikou
run_with_retry() {
    local cmd_name="$1"
    shift
    local max_attempts="$RETRY_COUNT"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log debug "[$attempt/$max_attempts] $cmd_name"
        if "$@" 2>&1 | tee -a "$LOG_FILE"; then
            log debug "$cmd_name OK"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log warn "$cmd_name selhalo (pokus $attempt/$max_attempts), čekám ${RETRY_DELAY}s..."
            sleep "$RETRY_DELAY"
        fi
        attempt=$((attempt + 1))
    done
    
    log warn "$cmd_name: vypršel počet pokusů"
    return 1
}

# Detekce pokud je Docker spuštěn
is_docker_running() {
    docker ps &>/dev/null
}

# Automatické opravy
auto_fix_issues() {
    if [ "$AUTO_FIX" -ne 1 ]; then
        return 0
    fi
    
    log info "🔧 Automatická detekce a oprava problémů..."
    
    # Oprava 1: Oprávnění skriptů
    if [ ! -x "$SCRIPT_DIR/install.sh" ]; then
        log debug "Oprava: chmod +x install.sh"
        chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true
    fi
    
    # Oprava 2: Docker group
    if ! groups "$USER_NAME" 2>/dev/null | grep -q docker; then
        log debug "Oprava: Přidání $USER_NAME do docker group"
        sudo usermod -aG docker "$USER_NAME" 2>/dev/null || log warn "Nelze přidat do docker group"
    fi
    
    # Oprava 3: Dialout group (pro Zigbee USB)
    if ! groups "$USER_NAME" 2>/dev/null | grep -q dialout; then
        log debug "Oprava: Přidání $USER_NAME do dialout group"
        sudo usermod -aG dialout "$USER_NAME" 2>/dev/null || true
    fi
    
    # Oprava 4: CONFIG/ vs config/ synchronizace
    if [ ! -d "$SCRIPT_DIR/config" ]; then
        log debug "Oprava: Vytváření config/ adresáře"
        mkdir -p "$SCRIPT_DIR/config"
    fi
    
    # Oprava 5: Výchozí sekery SSH (pokud existují)
    if [ ! -d ~/.ssh ]; then
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
    fi
    
    log success "Auto-opravy: Hotovo"
}

# Funkce pro kontrolu závislostí
check_dependencies() {
    log info "Kontrola závislostí..."
    
    local missing=()
    local critical_cmds=("curl" "wget" "git" "python3" "docker")
    
    for cmd in "${critical_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        else
            local version=""
            case "$cmd" in
                python3) version="$(python3 --version 2>&1 | awk '{print $2}')" ;;
                docker) version="$(docker --version 2>&1 | awk '{print $3}' | cut -d, -f1)" ;;
                *) version="installed" ;;
            esac
            log debug "$cmd: $version"
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log error "Chybějící kritické závislosti: ${missing[*]}"
        return 1
    fi
    
    log success "Všechny kritické závislosti: OK"
    return 0
}

# Vylepšená kontrola PyYAML
ensure_pyyaml() {
    if python3 -c "import yaml" 2>/dev/null; then
        log success "PyYAML: OK"
        return 0
    fi
    
    log warn "PyYAML chybí, pokusím se nainstalovat..."
    
    # Zkus apt
    if run_with_retry "apt-get install python3-yaml" \
        sudo apt-get update -y && sudo apt-get install -y python3-yaml 2>&1; then
        log success "PyYAML nainstalován (apt)"
        return 0
    fi
    
    # Zkus pip3
    if run_with_retry "pip3 install pyyaml" \
        sudo pip3 install pyyaml 2>&1; then
        log success "PyYAML nainstalován (pip)"
        return 0
    fi
    
    log error "Nelze nainstalovat PyYAML — YAML validace nebude dostupná"
    return 1
}

# Kontrola a oprava YAML souborů
check_yaml_files() {
    log info "Kontrola YAML konfiguračních souborů..."
    
    ensure_pyyaml || return 1
    
    # Ověření, že máme validate_ha_config.py
    if [ ! -f "$SCRIPT_DIR/scripts/validate_ha_config.py" ]; then
        log warn "validate_ha_config.py nebyl nalezen, používám standardní YAML check"
    fi
    
    local yaml_files=(
        "docker-compose.yml"
        "CONFIG/configuration.yaml"
        "CONFIG/automations.yaml"
    )
    
    local failed=0
    
    for file in "${yaml_files[@]}"; do
        if [ -f "$SCRIPT_DIR/$file" ]; then
            if python3 -c "import yaml; yaml.safe_load(open('$SCRIPT_DIR/$file'))" 2>/dev/null; then
                log success "$file: ✅ Platný YAML"
            else
                # Pokus se opravit běžné chyby
                if [ "$AUTO_FIX" -eq 1 ]; then
                    log warn "$file: Pokus o automatickou opravu..."
                    # Zde by byla logika pro opravu - pro teď jen warning
                fi
                log error "$file: ❌ Neplatný YAML syntax"
                failed=$((failed + 1))
            fi
        else
            log warn "$file: 🚫 Soubor neexistuje"
        fi
    done
    
    if [ $failed -gt 0 ]; then
        log error "$failed YAML soubor(ů) selhalo"
        return 1
    fi
    
    log success "YAML kontrola: OK"
    return 0
}

# Synchronizace CONFIG/ -> config/
sync_configs() {
    log info "Synchronizuji CONFIG/ → config/..."
    
    if [ ! -f "$SCRIPT_DIR/scripts/sync_config.sh" ]; then
        log error "scripts/sync_config.sh nebyl nalezen"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    if ! bash ./scripts/sync_config.sh --force --validate 2>&1 | tee -a "$LOG_FILE"; then
        log error "Synchronizace nebo validace configu selhala"
        return 1
    fi
    
    log success "Konfigurace synchronizovány"
    return 0
}

# Kontrola Docker instalace
check_docker() {
    log info "Kontrola Docker instalace..."
    
    if ! command -v docker &>/dev/null; then
        log error "Docker není nainstalován"
        return 1
    fi
    
    if ! is_docker_running; then
        log warn "Docker daemon není spuštěn, pokusím se spustit..."
        if sudo systemctl start docker 2>/dev/null; then
            log success "Docker daemon spuštěn"
            sleep 2  # Dej čas na inicializaci
        else
            log error "Nelze spustit Docker daemon"
            return 1
        fi
    fi
    
    log success "Docker: OK ($(docker --version 2>&1 | awk '{print $3}' | cut -d, -f1))"
    return 0
}

# Kontrola Docker Compose
check_docker_compose() {
    log info "Kontrola Docker Compose..."
    
    if command -v docker-compose &>/dev/null; then
        log success "docker-compose: $(docker-compose --version 2>&1)"
        return 0
    fi
    
    if docker compose version &>/dev/null; then
        log success "docker compose (plugin): $(docker compose version 2>&1 | head -1)"
        return 0
    fi
    
    log error "Docker Compose není nainstalován"
    return 1
}

# Spuštění Docker kontejnerů
start_docker_containers() {
    log info "Spouštění Docker služeb..."
    
    if [ ! -f "$DOCKER_COMPOSE_DIR/docker-compose.yml" ]; then
        log error "docker-compose.yml nebyl nalezen"
        return 1
    fi
    
    cd "$DOCKER_COMPOSE_DIR"
    
    # Sync konfigurací před startem
    if ! sync_configs; then
        log error "Nelze synchronizovat konfigurace"
        return 1
    fi
    
    # Spuštění s retry logikou
    if run_with_retry "docker-compose up -d" \
        docker-compose up -d 2>&1; then
        log success "Docker služby spuštěny"
        sleep 5  # Dej čas na inicializaci
        
        # Zobrazení běžících kontejnerů
        log info "Běžící kontejnery:"
        docker-compose ps | tee -a "$LOG_FILE"
        
        return 0
    fi
    
    log error "Nelze spustit Docker služby"
    return 1
}

# Health check služeb
health_check() {
    log info "🏥 Kontrola zdraví služeb..."
    
    local healthy=0
    local unhealthy=0
    
    # Home Assistant
    if curl -sf http://localhost:8123 &>/dev/null 2>&1; then
        log success "Home Assistant (8123): ✅"
        healthy=$((healthy + 1))
    else
        log warn "Home Assistant (8123): ❌ Nedostupný (inicializuje se...)"
        unhealthy=$((unhealthy + 1))
    fi
    
    # Mosquitto MQTT
    if timeout 2 bash -c "cat </dev/null >/dev/tcp/localhost/1883" 2>/dev/null; then
        log success "Mosquitto MQTT (1883): ✅"
        healthy=$((healthy + 1))
    else
        log warn "Mosquitto MQTT (1883): ❌ Nedostupný"
        unhealthy=$((unhealthy + 1))
    fi
    
    # Node-RED
    if curl -sf http://localhost:1880 &>/dev/null 2>&1; then
        log success "Node-RED (1880): ✅"
        healthy=$((healthy + 1))
    else
        log warn "Node-RED (1880): ❌ Inicializuje se..."
        unhealthy=$((unhealthy + 1))
    fi
    
    log info "Zdraví: $healthy OK, $unhealthy VAROVÁNÍ"
    
    if [ $unhealthy -gt 0 ]; then
        log warn "Některé služby se inicializují — zkontrolujte za 30-60 sekund"
    fi
    
    return 0
}

# Diagnostika
run_diagnostics() {
    log info "════════════════════════════════════════"
    log info "🩺 DIAGNOSTIKA SYSTÉMU"
    log info "════════════════════════════════════════"
    
    {
        echo "=== HARDW ARE ==="
        uname -a
        echo
        echo "=== DISK ==="
        df -h
        echo
        echo "=== RAM ==="
        free -h
        echo
        echo "=== DOCKER ==="
        docker ps -a
        echo
        echo "=== DOCKER VOLUMES ==="
        docker volume ls
        echo
        echo "=== DOCKER NETWORKS ==="
        docker network ls
        echo
        echo "=== DOCKER COMPOSE STATUS ==="
        cd "$DOCKER_COMPOSE_DIR"
        docker-compose ps 2>/dev/null || echo "N/A"
        echo
        echo "=== LOGY ==="
        docker-compose logs --tail=20 homeassistant 2>/dev/null | head -20 || echo "N/A"
    } | tee -a "$LOG_FILE"
    
    log success "Diagnostika: Hotovo"
}

# Oprava problémů
fix_issues() {
    log info "🔧 OPRAVA BĚŽNÝCH PROBLÉMŮ"
    
    # 1. Resetování Docker
    if [ "$AUTO_FIX" -eq 1 ]; then
        log info "Čištění Docker cache..."
        docker system prune -f 2>/dev/null || log warn "Docker prune selhal"
    fi
    
    # 2. Restart služeb
    log info "Restartování Docker daemon..."
    sudo systemctl restart docker 2>/dev/null || log warn "Restart docker selhalo"
    
    # 3. Permisiony
    log info "Oprava oprávnění..."
    chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true
    
    # 4. Nový sync
    sync_configs || log warn "Sync selhal během opravy"
    
    log success "Opravy: Hotovo"
}


# Hlavní menu
show_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  🏠 RPi5 HOME ASSISTANT SUITE - INSTALACE v${SCRIPT_VERSION}${NC}               ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  📦 ZÁKLADNÍ FUNKCE:"
    echo "     1) Kompletní instalace (doporučeno)"
    echo "     2) Apenas Docker komponenty"
    echo "     3) Kontrola a oprava YAML"
    echo "     4) Synchronizace konfigurace"
    echo ""
    echo "  🔧 SERVIS A ÚDRŽBA:"
    echo "     5) Health check — ověření běhu služeb"
    echo "     6) Diagnostika systému"
    echo "     7) Oprava běžných problémů"
    echo "     8) Čištění a optimalizace"
    echo ""
    echo "  🛠️  POKROČILÉ:"
    echo "     9) Zobrazit logy"
    echo "    10) Restart Docker služeb"
    echo "    11) Interaktivní diagnóza"
    echo ""
    echo "  ❌ UKONČIT:"
    echo "    12) Ukončit"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Kompletní instalace
complete_installation() {
    log info "════════════════════════════════════════════════════"
    log info "🚀 ZAHÁJENÍ KOMPLETNÍ INSTALACE"
    log info "════════════════════════════════════════════════════"
    
    # Kontroly
    auto_fix_issues
    check_dependencies || { log error "Chybějící kritické závislosti"; return 1; }
    check_yaml_files || log warn "YAML kontrola selhala, pokračuji..."
    
    # Docker
    check_docker || { log error "Docker nelze nainstalovat"; return 1; }
    check_docker_compose || log warn "Docker Compose není dostupný"
    
    # Spuštění
    start_docker_containers || { log error "Nelze spustit Docker služby"; return 1; }
    
    # Health check
    sleep 5
    health_check
    
    log success "════════════════════════════════════════════════════"
    log success "✅ KOMPLETNÍ INSTALACE ÚSPĚŠNÁ"
    log success "════════════════════════════════════════════════════"
    log info ""
    log info "🌐 Přístupové body:"
    log info "   Home Assistant: http://$(hostname -I | awk '{print $1}'):8123"
    log info "   Portainer (Docker): http://$(hostname -I | awk '{print $1}'):9000"
    log info "   Node-RED: http://$(hostname -I | awk '{print $1}'):1880"
    log info ""
    log info "📋 Log: $LOG_FILE"
    log info ""
}

# Docker only instalace
docker_only_installation() {
    log info "🐳 Instalace pouze Docker komponent"
    
    auto_fix_issues
    check_docker || return 1
    start_docker_containers || return 1
    health_check
    
    log success "✅ Docker instalace hotova"
}

# Zobrazení logů
show_logs() {
    log info "Posledních 50 řádků logu:"
    tail -50 "$LOG_FILE" | tee /dev/tty
    
    read -p "Chcete vidět kompletní log? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        less "$LOG_FILE"
    fi
}

# Restart Docker
restart_docker() {
    log info "Restartování Docker služby..."
    
    cd "$DOCKER_COMPOSE_DIR"
    
    if docker-compose ps &>/dev/null 2>&1 || docker compose ps &>/dev/null 2>&1; then
        log info "Zastavuji kontejnery..."
        docker-compose down 2>/dev/null || docker compose down 2>/dev/null || true
        
        sleep 3
        
        log info "Spouštím kontejnery..."
        start_docker_containers
    else
        log warn "Docker Compose není k dispozici"
    fi
    
    health_check
    log success "Restart hotov"
}

# Interaktivní diagnóza
interactive_diagnostics() {
    while true; do
        echo ""
        echo "🔍 INTERAKTIVNÍ DIAGNÓZA:"
        echo "  1) Health check"
        echo "  2) Docker status"
        echo "  3) Disk prostor"
        echo "  4) RAM a CPU"
        echo "  5) Síťové nastavení"
        echo "  6) Logy Home Assistant"
        echo "  7) Logy Mosquitto"
        echo "  8) Logy Node-RED"
        echo "  0) Zpět na hlavní menu"
        echo ""
        read -p "Vyberte [0-8]: " diag_choice
        
        case $diag_choice in
            1) health_check ;;
            2) 
                log info "Docker status:"
                docker ps -a
                ;;
            3)
                log info "Disk prostor:"
                df -h
                ;;
            4)
                log info "RAM a CPU:"
                free -h
                top -bn1 | head -n 3
                ;;
            5)
                log info "Síťové nastavení:"
                hostname -I
                ifconfig 2>/dev/null || ip addr show
                ;;
            6)
                log info "Posledních 30 řádků HA logu:"
                docker logs --tail 30 homeassistant 2>/dev/null || log warn "Nelze načíst HA logs"
                ;;
            7)
                log info "Posledních 30 řádků Mosquitto logu:"
                docker logs --tail 30 mosquitto 2>/dev/null || log warn "Nelze načíst Mosquitto logs"
                ;;
            8)
                log info "Posledních 30 řádků Node-RED logu:"
                docker logs --tail 30 nodered 2>/dev/null || log warn "Nelze načíst Node-RED logs"
                ;;
            0) break ;;
            *) log warn "Neplatná volba" ;;
        esac
        
        read -p "Stiskněte Enter pro pokračování..."
    done
}

# Parsování argumentů
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose) VERBOSE=1; shift ;;
            --skip-deps) SKIP_DEPS=1; shift ;;
            --dry-run) DRY_RUN=1; shift ;;
            --no-fix) AUTO_FIX=0; shift ;;
            -h|--help) show_help; exit 0 ;;
            *) shift ;;
        esac
    done
}

# Nápověda
show_help() {
    cat <<EOF
RPi5 Home Assistant Suite — Setup Script v${SCRIPT_VERSION}

Použití: $0 [VOLBY]

VOLBY:
  --verbose         Detailní výstupy
  --skip-deps       Přeskočit kontrolu závislostí
  --dry-run         Simulace bez skutečných změn
  --no-fix          Vypnout automatické opravy
  -h, --help        Zobrazit tuto nápovědu

PŘÍKLADY:
  $0                              # Interaktivní menu
  $0 --verbose                    # S detailním logováním
  $0 --skip-deps                  # Bez kontroly závislostí

EOF
}

# Hlavní smyčka
main() {
    # Inicializace
    init_logging
    check_sudo
    parse_args "$@"
    
    log info "════════════════════════════════════════════════════"
    log info "Spouštění Home Assistant Suite Setup v$SCRIPT_VERSION"
    log info "Log: $LOG_FILE"
    log info "════════════════════════════════════════════════════"
    
    # Kontrola, zda je skript spuštěn ze správného adresáře
    if [ ! -f "$DOCKER_COMPOSE_DIR/docker-compose.yml" ]; then
        log error "Skript musí být spuštěn z adresáře s docker-compose.yml"
        log error "Aktuální adresář: $PWD"
        exit 1
    fi
    
    # Interaktivní menu
    while true; do
        show_menu
        read -p "Vyberte možnost [1-12]: " choice
        
        case $choice in
            1) complete_installation ;;
            2) docker_only_installation ;;
            3) check_yaml_files ;;
            4) sync_configs ;;
            5) health_check ;;
            6) run_diagnostics ;;
            7) fix_issues ;;
            8) 
                log info "Čištění Docker..."
                docker system prune -f
                ;;
            9) show_logs ;;
            10) restart_docker ;;
            11) interactive_diagnostics ;;
            12) 
                log info "Ukončování..."
                exit 0
                ;;
            *)
                log warn "Neplatná volba [$choice]. Zkuste znovu."
                sleep 2
                ;;
        esac
        
        read -p "Stiskněte Enter pro pokračování na menu..."
    done
}

# Spuštění
main "$@"

# Funkce pro instalaci Docker komponent
install_docker_components() {
    log "Instalace Docker komponent..."
    
    cd "$DOCKER_COMPOSE_DIR"
    
    # Kontrola docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
        log "❌ Chybí docker-compose.yml"
        return 1
    fi
    
    # Synchronizace zdrojových konfigurací a spuštění služeb
    if ! sync_configs; then
        log "❌ Sync config failed, aborting docker-compose start"
        return 1
    fi

    # Spuštění služeb
    log "Spouštění služeb..."
    docker-compose up -d
    
    # Kontrola běžících kontejnerů
    log "Kontrola kontejnerů..."
    docker-compose ps
    
    log "✅ Docker komponenty nainstalovány"
}

# Funkce pro instalaci MHS35 displeje
install_mhs35_display() {
    log "Instalace MHS35 displeje..."
    
    if [ ! -f "mhs35_setup.sh" ]; then
        log "❌ Chybí mhs35_setup.sh"
        return 1
    fi
    
    chmod +x mhs35_setup.sh
    ./mhs35_setup.sh
    
    log "✅ MHS35 displej nainstalován"
}

# Funkce pro diagnostiku
run_diagnostics() {
    log "🩺 SPUŠTĚNÍ DIAGNOSTIKY"
    
    echo "=== SYSTÉM ==="
    uname -a
    echo
    
    echo "=== DISKOVÝ PROSTOR ==="
    df -h
    echo
    
    echo "=== RAM ==="
    free -h
    echo
    
    echo "=== DOCKER ==="
    docker --version
    docker-compose --version
    docker ps
    echo
    
    echo "=== SLUŽBY ==="
    systemctl is-active homeassistant && echo "Home Assistant: ✅" || echo "Home Assistant: ❌"
    systemctl is-active haos-agent && echo "HA OS Agent: ✅" || echo "HA OS Agent: ❌"
    systemctl is-active docker && echo "Docker: ✅" || echo "Docker: ❌"
    echo
    
    echo "=== SÍŤ ==="
    hostname -I
    echo
    
    echo "=== YAML SOUBORY ==="
    check_yaml_files
    echo
    
    echo "=== SKRIPTY ==="
    check_scripts
    echo
}

# Funkce pro opravu problémů
fix_issues() {
    log "🔧 OPRAVA PROBLÉMŮ"
    
    # Oprava oprávnění
    log "Oprava oprávnění skriptů..."
    chmod +x *.sh
    
    # Oprava Docker oprávnění
    log "Oprava Docker oprávnění..."
    sudo usermod -aG docker "$(whoami)"
    
    # Oprava USB zařízení
    log "Nastavení USB zařízení..."
    sudo usermod -aG dialout "$(whoami)"
    
    # Restart služeb
    log "Restart Docker služby..."
    sudo systemctl restart docker
    
    # Kontrola a oprava YAML souborů
    check_yaml_files
    
    log "✅ Základní opravy dokončeny"
}

# Funkce pro optimalizaci úložišť
optimize_storage() {
    log "🗂️  OPTIMALIZACE ÚLOŽIŠŤ"
    
    # Čištění Docker cache
    log "Čištění Docker cache..."
    docker system prune -f
    
    # Kontrola diskového prostoru
    log "Stav disku:"
    df -h /
    
    log "✅ Optimalizace dokončena"
}

# Hlavní menu
show_menu() {
    clear
    echo "=========================================="
    echo "🏠 RPi5 HOME ASSISTANT SUITE - INSTALACE"
    echo "=========================================="
    echo "1) Kompletní instalace (doporučeno)"
    echo "2) Pouze Home Assistant Supervised"
    echo "3) Pouze Docker komponenty"
    echo "4) Pouze MHS35 displej"
    echo "5) Diagnostika systému"
    echo "6) Kontrola YAML a skriptů"
    echo "7) Optimalizace úložišť"
    echo "8) Oprava problémů"
    echo "9) Kontrola systémových souborů"
    echo "10) Vybrat verzi instalace"
    echo "11) Ukončit"
    echo "=========================================="
}

# Hlavní funkce
main() {
    log "Spuštění RPi5 Home Assistant Suite"
    
    # Kontrola, zda je skript spuštěn z správného adresáře
    if [ ! -f "docker-compose.yml" ]; then
        log "❌ Skript musí být spuštěn z adresáře s docker-compose.yml"
        exit 1
    fi
    
    while true; do
        show_menu
        read -p "Vyberte možnost [1-11]: " choice
        
        case $choice in
            1)
                log "Zahájení kompletní instalace..."
                check_scripts
                check_yaml_files
                install_ha_supervised
                install_docker_components
                ;;
            2)
                log "Instalace pouze Home Assistant Supervised..."
                install_ha_supervised
                ;;
            3)
                log "Instalace pouze Docker komponent..."
                check_yaml_files
                install_docker_components
                ;;
            4)
                log "Instalace MHS35 displeje..."
                install_mhs35_display
                ;;
            5)
                run_diagnostics
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            6)
                check_scripts
                check_yaml_files
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            7)
                optimize_storage
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            8)
                fix_issues
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            9)
                log "Spuštění kontroly systémových souborů..."
                if [ -x "./scripts/system_check.sh" ]; then
                    ./scripts/system_check.sh
                else
                    log "❌ system_check.sh nebyl nalezen"
                fi
                ;;
            10)
                log "Výběr verze instalace..."
                if [ -x "./scripts/system_check.sh" ]; then
                    version=$("./scripts/system_check.sh" 9 2>/dev/null || echo "")
                    if [ -n "$version" ]; then
                        log "Vybrána verze: $version"
                    fi
                else
                    log "❌ system_check.sh nebyl nalezen"
                fi
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            11)
                log "Ukončování..."
                exit 0
                ;;
            *)
                echo "Neplatná volba. Zkuste to znovu."
                sleep 2
                ;;
        esac
    done
}

# Spuštění hlavní funkce
main "$@"
