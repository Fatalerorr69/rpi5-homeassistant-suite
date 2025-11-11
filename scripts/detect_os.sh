#!/bin/bash
# Multi-OS Detection & Adaptation
set -euo pipefail

# ======================================
# 🖥️ DETEKCE OPERAČNÍHO SYSTÉMU
# ======================================

# Soubor s informacemi o OS
OS_INFO_FILE="/etc/os-release"
LSB_RELEASE_FILE="/etc/lsb-release-codename"

# Barvy
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ⚠️ $1"; }
err() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ❌ $1"; }
info() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ℹ️ $1"; }

# ======================================
# DETEKCE OS
# ======================================

detect_os_family() {
    if [ -f "$OS_INFO_FILE" ]; then
        . "$OS_INFO_FILE"
        echo "$ID"
    else
        echo "unknown"
    fi
}

detect_os_version() {
    if [ -f "$OS_INFO_FILE" ]; then
        . "$OS_INFO_FILE"
        echo "${VERSION_ID:-unknown}"
    else
        echo "unknown"
    fi
}

detect_os_codename() {
    if [ -f "$OS_INFO_FILE" ]; then
        . "$OS_INFO_FILE"
        echo "${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || echo 'unknown')}"
    else
        echo "unknown"
    fi
}

detect_architecture() {
    uname -m
}

detect_kernel_version() {
    uname -r
}

detect_distro_pretty_name() {
    if [ -f "$OS_INFO_FILE" ]; then
        . "$OS_INFO_FILE"
        echo "$PRETTY_NAME"
    else
        uname -s
    fi
}

# ======================================
# KLASIFIKACE OS
# ======================================

is_debian_based() {
    local os=$(detect_os_family)
    case "$os" in
        debian|ubuntu|raspbian|armbian)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_rhel_based() {
    local os=$(detect_os_family)
    case "$os" in
        rhel|centos|rocky|fedora|alma)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_alpine() {
    local os=$(detect_os_family)
    [ "$os" = "alpine" ]
}

is_arch() {
    local os=$(detect_os_family)
    [ "$os" = "arch" ]
}

is_raspberry_pi() {
    if grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        return 0
    fi
    if grep -qi "rpi\|raspberry" /proc/cpuinfo 2>/dev/null; then
        return 0
    fi
    return 1
}

is_arm64() {
    [ "$(detect_architecture)" = "aarch64" ]
}

is_arm32() {
    [ "$(detect_architecture)" = "armv7l" ]
}

is_x86_64() {
    [ "$(detect_architecture)" = "x86_64" ]
}

# ======================================
# PACKAGE MANAGER FUNCTIONS
# ======================================

get_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v apk &>/dev/null; then
        echo "apk"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

install_package() {
    local pkg=$1
    local pm=$(get_package_manager)
    
    info "Instaluji $pkg..."
    
    case "$pm" in
        apt)
            sudo apt-get update -y
            sudo apt-get install -y "$pkg"
            ;;
        dnf|yum)
            sudo "$pm" install -y "$pkg"
            ;;
        apk)
            sudo apk add "$pkg"
            ;;
        pacman)
            sudo pacman -S --noconfirm "$pkg"
            ;;
        *)
            err "Neznámý package manager"
            return 1
            ;;
    esac
}

install_packages() {
    local packages=("$@")
    local pm=$(get_package_manager)
    
    info "Instaluji balíčky: ${packages[*]}"
    
    case "$pm" in
        apt)
            sudo apt-get update -y
            sudo apt-get install -y "${packages[@]}"
            ;;
        dnf|yum)
            sudo "$pm" install -y "${packages[@]}"
            ;;
        apk)
            sudo apk add "${packages[@]}"
            ;;
        pacman)
            sudo pacman -S --noconfirm "${packages[@]}"
            ;;
        *)
            err "Neznámý package manager"
            return 1
            ;;
    esac
}

# ======================================
# VÝSTUP INFORMACÍ
# ======================================

show_system_info() {
    echo ""
    echo "=========================================="
    echo "🖥️  INFORMACE O SYSTÉMU"
    echo "=========================================="
    echo ""
    echo -e "${MAGENTA}Operační systém:${NC}"
    echo "  • Název: $(detect_distro_pretty_name)"
    echo "  • Rodina: $(detect_os_family)"
    echo "  • Verze: $(detect_os_version)"
    echo "  • Codename: $(detect_os_codename)"
    echo ""
    echo -e "${MAGENTA}Hardware:${NC}"
    echo "  • Architektura: $(detect_architecture)"
    echo "  • Kernel: $(detect_kernel_version)"
    if is_raspberry_pi; then
        echo "  • Zařízení: 🍓 Raspberry Pi"
    else
        echo "  • Zařízení: $(uname -n)"
    fi
    echo ""
    echo -e "${MAGENTA}Správce balíčků:${NC}"
    echo "  • $(get_package_manager)"
    echo ""
    echo -e "${MAGENTA}Klasifikace:${NC}"
    if is_debian_based; then
        echo "  ✅ Debian-based (APT)"
    fi
    if is_rhel_based; then
        echo "  ✅ RHEL-based (DNF/YUM)"
    fi
    if is_alpine; then
        echo "  ✅ Alpine (APK)"
    fi
    if is_arm64; then
        echo "  ✅ ARM 64-bit (aarch64)"
    fi
    if is_arm32; then
        echo "  ✅ ARM 32-bit (armv7l)"
    fi
    if is_x86_64; then
        echo "  ✅ x86-64"
    fi
    echo ""
    echo "=========================================="
    echo ""
}

# ======================================
# KOMPATIBILITA KONTROLY
# ======================================

check_compatibility() {
    local os=$(detect_os_family)
    local arch=$(detect_architecture)
    local compatible=true
    
    info "Kontrola kompatibility..."
    echo ""
    
    # Architektura
    case "$arch" in
        aarch64|armv7l)
            log "✅ Architektura je podporována (ARM)"
            ;;
        x86_64)
            warn "⚠️ x86-64 není optimalizován, ale měl by fungovat"
            ;;
        *)
            err "❌ Architektura $arch není podporována"
            compatible=false
            ;;
    esac
    
    # OS
    case "$os" in
        debian|ubuntu|raspbian|armbian)
            log "✅ Debian/Ubuntu je plně podporován"
            ;;
        rocky|centos|rhel|fedora|alma)
            warn "⚠️ RHEL-based OS je částečně podporován"
            ;;
        alpine)
            warn "⚠️ Alpine je experimentální"
            ;;
        *)
            err "❌ OS $os není podporován"
            compatible=false
            ;;
    esac
    
    if [ "$compatible" = true ]; then
        log "✅ Systém je kompatibilní"
        return 0
    else
        err "❌ Systém nemusí být kompatibilní"
        return 1
    fi
}

# ======================================
# EXPORT FUNKCÍ PRO OSTATNÍ SKRIPTY
# ======================================

export_os_functions() {
    cat > /tmp/os-detection.sh << 'EOF'
# Tento soubor je generován detect_os.sh
# Importujte jej v jiných skriptech: source /tmp/os-detection.sh

OS_FAMILY="$(source /etc/os-release 2>/dev/null && echo $ID || echo unknown)"
OS_VERSION="$(source /etc/os-release 2>/dev/null && echo ${VERSION_ID:-unknown} || echo unknown)"
OS_ARCH="$(uname -m)"
PACKAGE_MANAGER="$(command -v apt-get >/dev/null && echo apt || command -v dnf >/dev/null && echo dnf || command -v yum >/dev/null && echo yum || command -v apk >/dev/null && echo apk || echo unknown)"

is_debian() { [ "$PACKAGE_MANAGER" = "apt" ]; }
is_rhel() { [ "$PACKAGE_MANAGER" = "dnf" ] || [ "$PACKAGE_MANAGER" = "yum" ]; }
is_alpine() { [ "$PACKAGE_MANAGER" = "apk" ]; }
is_arm64() { [ "$OS_ARCH" = "aarch64" ]; }
is_arm32() { [ "$OS_ARCH" = "armv7l" ]; }

export OS_FAMILY OS_VERSION OS_ARCH PACKAGE_MANAGER
EOF
    log "✅ Funkce exportovány do /tmp/os-detection.sh"
}

# ======================================
# MENU
# ======================================

show_menu() {
    echo ""
    echo "=========================================="
    echo "🖥️  DETEKCE OPERAČNÍHO SYSTÉMU"
    echo "=========================================="
    echo ""
    echo "1) Zobrazit informace o systému"
    echo "2) Kontrola kompatibility"
    echo "3) Exportovat detekční funkce"
    echo "4) Instalovat balíček (interactive)"
    echo "5) Vše (informace + kompatibilita + export)"
    echo "6) Nastavit proměnné prostředí"
    echo "7) Výstup pro skript"
    echo "0) Ukončit"
    echo ""
}

set_environment_variables() {
    export OS_FAMILY=$(detect_os_family)
    export OS_VERSION=$(detect_os_version)
    export OS_CODENAME=$(detect_os_codename)
    export OS_ARCH=$(detect_architecture)
    export KERNEL_VERSION=$(detect_kernel_version)
    export PACKAGE_MANAGER=$(get_package_manager)
    
    log "✅ Proměnné prostředí nastaveny:"
    echo "  • OS_FAMILY=$OS_FAMILY"
    echo "  • OS_VERSION=$OS_VERSION"
    echo "  • OS_CODENAME=$OS_CODENAME"
    echo "  • OS_ARCH=$OS_ARCH"
    echo "  • KERNEL_VERSION=$KERNEL_VERSION"
    echo "  • PACKAGE_MANAGER=$PACKAGE_MANAGER"
}

output_for_script() {
    cat << EOF
#!/bin/bash
# Auto-generated by detect_os.sh
export OS_FAMILY="$(detect_os_family)"
export OS_VERSION="$(detect_os_version)"
export OS_CODENAME="$(detect_os_codename)"
export OS_ARCH="$(detect_architecture)"
export KERNEL_VERSION="$(detect_kernel_version)"
export PACKAGE_MANAGER="$(get_package_manager)"
EOF
}

# ======================================
# HLAVNÍ PROGRAM
# ======================================

main() {
    if [ $# -eq 0 ]; then
        # Interactive menu
        while true; do
            show_menu
            read -p "Vyberte [0-7]: " choice
            case $choice in
                1) show_system_info ;;
                2) check_compatibility ;;
                3) export_os_functions ;;
                4) read -p "Balíček: " pkg; install_package "$pkg" ;;
                5) show_system_info; check_compatibility; export_os_functions ;;
                6) set_environment_variables ;;
                7) output_for_script ;;
                0) log "Ukončuji..."; exit 0 ;;
                *) err "Neplatná volba" ;;
            esac
        done
    else
        # Command-line arguments
        case "$1" in
            --detect-os)      detect_os_family ;;
            --detect-version) detect_os_version ;;
            --detect-codename) detect_os_codename ;;
            --detect-arch)    detect_architecture ;;
            --detect-kernel)  detect_kernel_version ;;
            --detect-pretty)  detect_distro_pretty_name ;;
            --pm)             get_package_manager ;;
            --is-debian)      is_debian_based && echo "yes" || echo "no" ;;
            --is-rhel)        is_rhel_based && echo "yes" || echo "no" ;;
            --is-alpine)      is_alpine && echo "yes" || echo "no" ;;
            --is-arm64)       is_arm64 && echo "yes" || echo "no" ;;
            --is-arm32)       is_arm32 && echo "yes" || echo "no" ;;
            --is-rpi)         is_raspberry_pi && echo "yes" || echo "no" ;;
            --check)          check_compatibility ;;
            --info)           show_system_info ;;
            --export)         export_os_functions ;;
            --env)            set_environment_variables ;;
            --output)         output_for_script ;;
            *)
                err "Neznámá volba: $1"
                echo "Použití: $0 [--detect-os|--detect-version|--detect-arch|--pm|--is-debian|--is-rhel|--check|--info|--export|--env|--output]"
                exit 1
                ;;
        esac
    fi
}

main "$@"
