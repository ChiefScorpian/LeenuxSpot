#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# LeenuxSpot Installer
# ============================================================

INSTALL_DIR="/usr/local/bin"
TARGET="$INSTALL_DIR/leenuxctl"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/leenuxctl"

echo
echo "LeenuxSpot Installer"
echo "===================="
echo

# ------------------------------------------------------------
# Root check
# ------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Error: run the installer with sudo."
    echo
    echo "Example:"
    echo "  sudo ./install.sh"
    exit 1
fi

# ------------------------------------------------------------
# Detect Linux distribution
# ------------------------------------------------------------

if [[ ! -f /etc/os-release ]]; then
    echo "Error: cannot determine Linux distribution."
    exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release

DISTRO_ID="${ID:-unknown}"
DISTRO_LIKE="${ID_LIKE:-}"

echo "Detected operating system:"
echo "  ${PRETTY_NAME:-$DISTRO_ID}"
echo

# ------------------------------------------------------------
# Detect package manager
# ------------------------------------------------------------

PACKAGE_MANAGER=""

if command -v apt-get >/dev/null 2>&1; then
    PACKAGE_MANAGER="apt"
elif command -v dnf >/dev/null 2>&1; then
    PACKAGE_MANAGER="dnf"
elif command -v yum >/dev/null 2>&1; then
    PACKAGE_MANAGER="yum"
elif command -v pacman >/dev/null 2>&1; then
    PACKAGE_MANAGER="pacman"
elif command -v zypper >/dev/null 2>&1; then
    PACKAGE_MANAGER="zypper"
fi

if [[ -z "$PACKAGE_MANAGER" ]]; then
    echo "Warning: no supported package manager was detected."
    echo
    echo "LeenuxSpot requires:"
    echo "  NetworkManager"
    echo "  nftables"
    echo "  dnsmasq"
    echo "  conntrack"
    echo "  dig"
    echo "  Python 3"
    echo "  iproute2"
    echo
    echo "Please install these packages manually."
    echo
else
    echo "Package manager:"
    echo "  $PACKAGE_MANAGER"
    echo
fi

# ------------------------------------------------------------
# Package names
# ------------------------------------------------------------

PACKAGES=()

case "$PACKAGE_MANAGER" in

    apt)
        PACKAGES=(
            network-manager
            nftables
            dnsmasq
            conntrack
            dnsutils
            python3
            iproute2
        )
        ;;

    dnf|yum)
        PACKAGES=(
            NetworkManager
            nftables
            dnsmasq
            conntrack-tools
            bind-utils
            python3
            iproute
        )
        ;;

    pacman)
        PACKAGES=(
            networkmanager
            nftables
            dnsmasq
            conntrack-tools
            bind
            python
            iproute2
        )
        ;;

    zypper)
        PACKAGES=(
            NetworkManager
            nftables
            dnsmasq
            conntrack-tools
            bind-utils
            python3
            iproute2
        )
        ;;

esac

# ------------------------------------------------------------
# Required commands
# ------------------------------------------------------------

declare -A REQUIRED_COMMANDS=(
    [nmcli]="NetworkManager"
    [nft]="nftables"
    [dnsmasq]="dnsmasq"
    [conntrack]="conntrack"
    [dig]="dig"
    [python3]="Python 3"
    [ip]="iproute2"
)

MISSING=()

echo "Checking dependencies..."
echo

for command_name in "${!REQUIRED_COMMANDS[@]}"; do
    description="${REQUIRED_COMMANDS[$command_name]}"

    if command -v "$command_name" >/dev/null 2>&1; then
        echo "  ✓ $description"
    else
        echo "  ✗ $description"
        MISSING+=("$command_name")
    fi
done

echo

# ------------------------------------------------------------
# Install missing dependencies
# ------------------------------------------------------------

if (( ${#MISSING[@]} > 0 )); then

    echo "Missing dependencies:"
    echo

    for command_name in "${MISSING[@]}"; do
        echo "  - ${REQUIRED_COMMANDS[$command_name]}"
    done

    echo

    if [[ -z "$PACKAGE_MANAGER" ]]; then
        echo "No supported package manager was detected."
        echo "Please install the missing dependencies manually."
        exit 1
    fi

    echo "LeenuxSpot can install the required packages."
    echo

    read -r -p "Install missing dependencies now? [Y/n]: " answer

    case "${answer:-Y}" in
        y|Y|yes|YES)
            ;;
        *)
            echo
            echo "Installation cancelled."
            echo "Please install the missing dependencies and run"
            echo "the installer again."
            exit 1
            ;;
    esac

    echo
    echo "Installing dependencies..."
    echo

    case "$PACKAGE_MANAGER" in

        apt)
            export DEBIAN_FRONTEND=noninteractive

            apt-get update
            apt-get install -y "${PACKAGES[@]}"
            ;;

        dnf)
            dnf install -y "${PACKAGES[@]}"
            ;;

        yum)
            yum install -y "${PACKAGES[@]}"
            ;;

        pacman)
            pacman -Sy --needed --noconfirm "${PACKAGES[@]}"
            ;;

        zypper)
            zypper --non-interactive install "${PACKAGES[@]}"
            ;;

    esac

    echo
    echo "Dependency installation complete."
    echo

    # --------------------------------------------------------
    # Verify dependencies again
    # --------------------------------------------------------

    echo "Verifying dependencies..."
    echo

    FAILED=0

    for command_name in "${!REQUIRED_COMMANDS[@]}"; do
        description="${REQUIRED_COMMANDS[$command_name]}"

        if command -v "$command_name" >/dev/null 2>&1; then
            echo "  ✓ $description"
        else
            echo "  ✗ $description"
            FAILED=1
        fi
    done

    echo

    if (( FAILED != 0 )); then
        echo "ERROR: some required dependencies are still missing."
        echo
        echo "Please install them manually and run the installer again."
        exit 1
    fi
fi

# ------------------------------------------------------------
# Verify NetworkManager service
# ------------------------------------------------------------

if command -v systemctl >/dev/null 2>&1; then
    echo "Checking NetworkManager service..."

    if systemctl is-active --quiet NetworkManager; then
        echo "  ✓ NetworkManager is running"
    else
        echo "  ! NetworkManager is installed but not running"

        read -r -p "Start NetworkManager now? [Y/n]: " answer

        case "${answer:-Y}" in
            y|Y|yes|YES)
                systemctl enable --now NetworkManager
                echo "  ✓ NetworkManager started"
                ;;
            *)
                echo "  ! NetworkManager was not started"
                ;;
        esac
    fi

    echo
fi

# ------------------------------------------------------------
# Verify source
# ------------------------------------------------------------

if [[ ! -f "$SOURCE" ]]; then
    echo "Error: leenuxctl was not found."
    echo
    echo "Expected:"
    echo "  $SOURCE"
    exit 1
fi

# ------------------------------------------------------------
# Create installation directory
# ------------------------------------------------------------

mkdir -p "$INSTALL_DIR"

# ------------------------------------------------------------
# Backup existing installation
# ------------------------------------------------------------

if [[ -f "$TARGET" ]]; then
    TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
    BACKUP="${TARGET}.backup-${TIMESTAMP}"

    echo "Existing leenuxctl detected."
    echo
    echo "Creating backup:"
    echo "  $BACKUP"
    echo

    cp -a "$TARGET" "$BACKUP"
fi

# ------------------------------------------------------------
# Install
# ------------------------------------------------------------

echo "Installing leenuxctl..."
echo

install -m 755 "$SOURCE" "$TARGET"

# ------------------------------------------------------------
# Verify installation
# ------------------------------------------------------------

if [[ ! -x "$TARGET" ]]; then
    echo "ERROR: installation verification failed."
    exit 1
fi

if ! "$TARGET" help >/dev/null 2>&1; then
    echo "ERROR: installed leenuxctl failed its basic startup test."
    exit 1
fi

echo "Installation successful!"
echo
echo "Installed:"
echo "  $TARGET"
echo

# ------------------------------------------------------------
# Finished
# ------------------------------------------------------------

echo "Try:"
echo
echo "  sudo leenuxctl help"
echo "  sudo leenuxctl status"
echo "  sudo leenuxctl doctor"
echo

echo "To configure a hotspot:"
echo
echo "  sudo leenuxctl setup --name LeenuxSpot --password 'your-password' --upstream wlan0 --hotspot wlan1"
echo
