#!/bin/bash

# ==========================================
# 📋 KONTROLA SYSTÉMOVÝCH SOUBORŮ
# ==========================================
# Skript pro verifikaci integrity souborů a výběr verzí instalace
# Verze: 1.0

set -euo pipefail

# Proměnné
LOG_FILE="/home/$(whoami)/system_check.log"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Funkce pro logování
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ==========================================
# 1. KONTROLA SYSTÉMOVÝCH SOUBORŮ
# ==========================================

# Kontrola Bash skriptů
check_bash_scripts() {
    log "🔍 Kontrola Bash skriptů (syntaxe)..."
    
    local failed=0
    local count=0
    
    while IFS= read -r -d '' script; do
        ((count++))
        if bash -n "$script" 2>/dev/null; then
            log "  ✅ $script"
        else
            log "  ❌ $script — CHYBA v syntaxi!"
            ((failed++))
        fi
    done < <(find "$REPO_ROOT" -maxdepth 3 -name "*.sh" -type f -print0)
    
    log "Skriptů kontroleno: $count, Chyb: $failed"
    return $((failed > 0 ? 1 : 0))
}

# Kontrola YAML souborů
check_yaml_files() {
    log "🔍 Kontrola YAML souborů..."
    
    # Zajistit PyYAML
    if ! python3 -c "import yaml" 2>/dev/null; then
        log "⚠️  PyYAML není nainstalován, instaluji..."
        sudo apt-get update -y && sudo apt-get install -y python3-yaml 2>/dev/null || \
            sudo pip3 install pyyaml 2>/dev/null || true
    fi
    
    local failed=0
    local count=0
    
    while IFS= read -r -d '' yaml_file; do
        ((count++))
        if python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
            log "  ✅ $yaml_file"
        else
            log "  ❌ $yaml_file — CHYBA v YAML!"
            ((failed++))
        fi
    done < <(find "$REPO_ROOT" -maxdepth 3 -name "*.yaml" -o -name "*.yml" -type f -print0)
    
    log "YAML souborů kontroleno: $count, Chyb: $failed"
    return $((failed > 0 ? 1 : 0))
}

# Kontrola Markdown souborů
check_markdown_files() {
    log "🔍 Kontrola Markdown souborů..."
    
    local failed=0
    local count=0
    
    while IFS= read -r -d '' md_file; do
        ((count++))
        # Základní kontrola: alespoň jeden heading
        if grep -q "^#" "$md_file" 2>/dev/null; then
            log "  ✅ $md_file"
        else
            log "  ⚠️  $md_file — Bez headingů?"
        fi
    done < <(find "$REPO_ROOT" -maxdepth 2 -name "*.md" -type f -print0)
    
    log "Markdown souborů kontroleno: $count"
    return 0
}

# Kontrola doporučené struktury adresářů
check_directory_structure() {
    log "🔍 Kontrola struktury adresářů..."
    
    local required_dirs=(
        "scripts"
        "POST_INSTALL"
        "CONFIG"
        "config"
        "docs"
        "tests"
        "ansible"
        ".github"
    )
    
    local missing=0
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$REPO_ROOT/$dir" ]; then
            log "  ✅ $dir/"
        else
            log "  ❌ $dir/ — CHYBÍ!"
            ((missing++))
        fi
    done
    
    return $((missing > 0 ? 1 : 0))
}

# Kontrola doporučených souborů
check_required_files() {
    log "🔍 Kontrola kritických souborů..."
    
    local required_files=(
        "setup_master.sh"
        "install.sh"
        "docker-compose.yml"
        "README.md"
        "CHANGELOG.md"
        ".github/copilot-instructions.md"
    )
    
    local missing=0
    
    for file in "${required_files[@]}"; do
        if [ -f "$REPO_ROOT/$file" ]; then
            log "  ✅ $file"
        else
            log "  ❌ $file — CHYBÍ!"
            ((missing++))
        fi
    done
    
    return $((missing > 0 ? 1 : 0))
}

# Kontrola oprávnění skriptů
check_script_permissions() {
    log "🔍 Kontrola oprávnění skriptů..."
    
    local not_executable=0
    
    while IFS= read -r -d '' script; do
        if [ ! -x "$script" ]; then
            log "  ⚠️  $script — Není executable (chmod +x)"
            ((not_executable++))
        else
            log "  ✅ $script"
        fi
    done < <(find "$REPO_ROOT" -maxdepth 3 -name "*.sh" -type f -print0)
    
    if [ $not_executable -gt 0 ]; then
        log "Oprava oprávnění..."
        find "$REPO_ROOT" -maxdepth 3 -name "*.sh" -type f -exec chmod +x {} \;
        log "✅ Oprávnění opravena"
    fi
    
    return 0
}

# Kontrola velikosti souborů
check_file_sizes() {
    log "🔍 Kontrola velikostí skriptů..."
    
    while IFS= read -r -d '' script; do
        local size=$(wc -c < "$script")
        local size_kb=$((size / 1024))
        if [ $size -lt 50 ]; then
            log "  ⚠️  $script — Velmi malý soubor ($size bajtů)"
        elif [ $size -gt 50000 ]; then
            log "  ⚠️  $script — Velký soubor ($size_kb KB)"
        else
            log "  ✅ $script"
        fi
    done < <(find "$REPO_ROOT" -maxdepth 3 -name "*.sh" -type f -print0)
    
    return 0
}

# ==========================================
# 2. VÝBĚR VERZÍ INSTALACE
# ==========================================

# Detekce dostupných verzí
detect_available_versions() {
    log "📦 Detekce dostupných verzí..."
    
    local versions=()
    
    # Kontrola docker-compose verzí
    if [ -f "$REPO_ROOT/docker-compose.yml" ]; then
        versions+=("docker-compose-homeassistant")
    fi
    if [ -f "$REPO_ROOT/CONFIG/docker-compose-homeassistant.yml" ]; then
        versions+=("docker-compose-config")
    fi
    
    # Kontrola Home Assistant verzí
    if [ -d "$REPO_ROOT/INSTALLATION" ]; then
        for installer in "$REPO_ROOT/INSTALLATION/"*.sh; do
            if [ -f "$installer" ]; then
                versions+=("$(basename "$installer" .sh)")
            fi
        done
    fi
    
    # Kontrola Hardware verzí
    if [ -d "$REPO_ROOT/HARDWARE" ]; then
        for hw_setup in "$REPO_ROOT/HARDWARE/"*.sh; do
            if [ -f "$hw_setup" ]; then
                versions+=("hw-$(basename "$hw_setup" .sh)")
            fi
        done
    fi
    
    echo "${versions[@]}"
}

# Zobrazení dostupných verzí instalace
show_installation_versions() {
    clear
    echo "=========================================="
    echo "📦 DOSTUPNÉ VERZE INSTALACE"
    echo "=========================================="
    
    local versions=($(detect_available_versions))
    
    if [ ${#versions[@]} -eq 0 ]; then
        log "❌ Žádné verze instalace nebyly nalezeny"
        return 1
    fi
    
    # Kategorie Home Assistant
    echo ""
    echo "🏠 HOME ASSISTANT INSTALACE:"
    echo "  1) Home Assistant Supervised (docker + supervised mode)"
    echo "  2) Home Assistant Docker (pouze docker, bez supervised)"
    echo "  3) Home Assistant Full Suite (všechny komponenty)"
    
    # Kategorie Hardware
    echo ""
    echo "🖥️  HARDWARE SPECIFICKÉ:"
    echo "  4) MHS35 TFT Display (interaktivní setup)"
    echo "  5) MHS35 Auto Setup (plně automatický)"
    echo "  6) Minimální setup (jen základy)"
    
    # Kategorie Docker Compose
    echo ""
    echo "🐳 DOCKER COMPOSE:"
    echo "  7) Standard Docker Compose"
    echo "  8) Home Assistant Docker Compose"
    echo "  9) Vlastní konfiguraci"
    
    echo ""
    echo "=========================================="
}

# Menu pro výběr verze
select_installation_version() {
    show_installation_versions
    
    read -p "Vyberte verzi instalace [1-9]: " version_choice
    
    case $version_choice in
        1)
            log "✅ Vybrána instalace: Home Assistant Supervised"
            echo "install-ha-supervised"
            ;;
        2)
            log "✅ Vybrána instalace: Home Assistant Docker"
            echo "install-ha-docker"
            ;;
        3)
            log "✅ Vybrána instalace: Full Suite"
            echo "install-full-suite"
            ;;
        4)
            log "✅ Vybrána instalace: MHS35 Interactive"
            echo "install-mhs35-interactive"
            ;;
        5)
            log "✅ Vybrána instalace: MHS35 Auto"
            echo "install-mhs35-auto"
            ;;
        6)
            log "✅ Vybrána instalace: Minimální"
            echo "install-minimal"
            ;;
        7)
            log "✅ Vybrána instalace: Standard Docker Compose"
            echo "install-docker-compose"
            ;;
        8)
            log "✅ Vybrána instalace: HA Docker Compose"
            echo "install-ha-docker-compose"
            ;;
        9)
            log "✅ Vybrána instalace: Vlastní"
            echo "install-custom"
            ;;
        *)
            log "❌ Neplatná volba"
            return 1
            ;;
    esac
}

# ==========================================
# 3. REPORTOVÁNÍ
# ==========================================

# Celkový report
generate_report() {
    log "📊 GENEROVÁNÍ REPORTU..."
    
    echo ""
    echo "=========================================="
    echo "📋 REPORT KONTROLY SYSTÉMU"
    echo "=========================================="
    echo "Čas: $(date)"
    echo "Repo: $REPO_ROOT"
    echo ""
    
    # Počty souborů
    local bash_count=$(find "$REPO_ROOT" -maxdepth 3 -name "*.sh" -type f | wc -l)
    local yaml_count=$(find "$REPO_ROOT" -maxdepth 3 \( -name "*.yaml" -o -name "*.yml" \) -type f | wc -l)
    local md_count=$(find "$REPO_ROOT" -maxdepth 2 -name "*.md" -type f | wc -l)
    
    echo "📊 POČTY SOUBORŮ:"
    echo "  Bash skripty: $bash_count"
    echo "  YAML soubory: $yaml_count"
    echo "  Markdown: $md_count"
    echo ""
    
    # Git info (pokud je repo)
    if cd "$REPO_ROOT" && git rev-parse --git-dir > /dev/null 2>&1; then
        echo "📦 GIT INFORMACE:"
        echo "  Branch: $(git rev-parse --abbrev-ref HEAD)"
        echo "  Commits: $(git rev-list --count HEAD)"
        echo "  Last commit: $(git log -1 --format=%ci)"
        echo ""
    fi
    
    # Systém
    echo "🖥️  SYSTÉM:"
    echo "  OS: $(uname -s)"
    echo "  Kernel: $(uname -r)"
    echo "  Disk: $(df -h / | tail -1 | awk '{print $2, "("$5" použito)"}')"
    echo "  RAM: $(free -h | grep Mem | awk '{print $2, "("$3" použito)"}')"
    echo ""
    
    echo "=========================================="
}

# ==========================================
# HLAVNÍ MENU
# ==========================================

show_main_menu() {
    clear
    echo "=========================================="
    echo "📋 KONTROLA SYSTÉMOVÝCH SOUBORŮ"
    echo "=========================================="
    echo "1) Kompletní kontrola všech souborů"
    echo "2) Kontrola Bash skriptů (syntaxe)"
    echo "3) Kontrola YAML souborů"
    echo "4) Kontrola Markdown dokumentace"
    echo "5) Kontrola struktury adresářů"
    echo "6) Kontrola kritických souborů"
    echo "7) Kontrola oprávnění skriptů (a oprava)"
    echo "8) Kontrola velikostí souborů"
    echo "9) Vybrat verzi instalace"
    echo "10) Generovat report"
    echo "11) Ukončit"
    echo "=========================================="
}

# Hlavní funkce
main() {
    log "Spuštění kontroly systému"
    
    while true; do
        show_main_menu
        read -p "Vyberte možnost [1-11]: " choice
        
        case $choice in
            1)
                echo ""
                check_directory_structure && \
                check_required_files && \
                check_bash_scripts && \
                check_yaml_files && \
                check_markdown_files && \
                check_script_permissions && \
                check_file_sizes && \
                log "✅ Všechny kontroly dokončeny" || \
                log "❌ Některé kontroly selhaly"
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            2)
                check_bash_scripts || log "❌ Kontrola selhala"
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            3)
                check_yaml_files || log "❌ Kontrola selhala"
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            4)
                check_markdown_files || log "❌ Kontrola selhala"
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            5)
                check_directory_structure || log "❌ Kontrola selhala"
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            6)
                check_required_files || log "❌ Kontrola selhala"
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            7)
                check_script_permissions
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            8)
                check_file_sizes
                read -p "Stiskněte Enter pro pokračování..."
                ;;
            9)
                version=$(select_installation_version)
                if [ -n "$version" ]; then
                    log "Vybraná verze: $version"
                    read -p "Stiskněte Enter pro pokračování..."
                fi
                ;;
            10)
                generate_report
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

# Spuštění
main "$@"
