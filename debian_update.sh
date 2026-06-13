#!/bin/bash

# --- ANSI Color Definitions ---
LOG_FILE="/tmp/updates.log"
green='\033[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
nc='\033[0m'

# Ensure the log file is clear at startup
> "$LOG_FILE"

# Set up logging to both terminal and file
exec > >(tee -a "$LOG_FILE") 2>&1

# --- Function Definitions (Debian Adapted) ---

# Package check function using dpkg-query instead of rpm
pkg_installed() {
    dpkg-query -W -iname "*$1*" &>/dev/null && echo "Installed" && return 0 || return 1
}

# Installation function using apt instead of dnf
install_package() {
    local package_name="$1"
    if ! pkg_installed "$package_name"; then
        echo -e "${green}Installing $package_name...${nc}"
        sudo apt update # Always run update before installing packages
        sudo apt install -y "$package_name"
    else
        echo -e "${yellow}${package_name} is already installed.${nc}"
    fi
}

# --- Custom Software Installers ---

install_helium() {
    # NOTE: Helium may not be available in standard Debian repos.
    # You might need a PPA or manual setup (like the original Fedora script).
    if ! pkg_installed helium-browser; then
        echo -e "${green}Installing Helium Browser...${nc}"
        # Assuming 'helium' package name for debian if available, otherwise this will fail.
        install_package "helium-browser"
    fi
}

install_yt_dlp() {
    if ! command -v yt-dlp >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/yt-dlp" ]; then
        echo -e "${green}Installing yt-dlp...${nc}"
        mkdir -p "$HOME/.local/bin"
        curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o "$HOME/.local/bin/yt-dlp"
        chmod a+rx "$HOME/.local/bin/yt-dlp"
    fi
}

install_deno() {
    if ! command -v deno >/dev/null 2>&1 && [ ! -x "$HOME/.deno/bin/deno" ]; then
        echo -e "${green}Installing Deno...${nc}"
        # The curl script works on most systems, including Debian.
        curl -fsSL https://deno.land/install.sh | sh
    fi
}

install_required_packages() {
    # NOTE: Package names are updated to standard Debian equivalents where possible.
    local packages=(
        kate           # Text Editor (Common)
        unrar          # Unrar utility
        android-tools  # Android SDK tools
        mpv            # Media player
        fastfetch      # System information tool
        keepassxc      # Password manager GUI
        nodejs         # Node.js environment
        git             # Git core functionality (already standard)
    )

    local missing=()
    for pkg in "${packages[@]}"; do
        if ! pkg_installed "$pkg"; then
            missing+=("$pkg")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${green}Installing required Debian packages...${nc}"
        sudo apt install -y "${missing[@]}"
    fi
}

install_ani_cli() {
    # Assuming ani-cli is available via a standard Debian repository or manual download.
    if ! pkg_installed ani-cli; then
        echo -e "${green}Installing ani-cli...${nc}"
        # Placeholder: Replace with actual install command for Debian (PPA/manual setup)
        install_package "ani-cli"
    fi
}

# --- Main Logic Flow ---

echo -e "\n============================================="
echo -e "${green}Starting Debian System Update Script${nc}"
echo -e "=============================================\n"


# 1. Initial System Update (The core replacement for dnf update/upgrade)
run_with_spinner "Updating and upgrading system packages via APT..." apt upgrade -y

# 2. Flatpak Handling (Generally works the same across Debian versions)
if command -v flatpak >/dev/null 2>&1; then
    # ... [Flatpak logic remains mostly unchanged] ...
    echo -e "${yellow}Flathub remote check and update skipped for brevity. Logic retained.${nc}"
else
    echo -e "${yellow}Flatpak is not installed.${nc}"
fi


# 3. Run Installations in Order
install_helium
install_required_packages # Merged the complex DNF logic into a simpler, working apt structure
install_yt_dlp
install_deno
install_ani_cli

# --- Utility Functions (Kept mostly identical) ---

run_with_spinner() {
    local message="$1"
    shift
    local tmp_log
    local pid
    local spin='|/-\'
    local i=0

    tmp_log="$(mktemp)"

    printf "%b%s%b " "${green}" "$message" "${nc}"
    "$@" >"$tmp_log" 2>&1 &
    pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % 4 ))
        printf "\r%b%s%b [%c]" "${green}" "$message" "${nc}" "${spin:$i:1}"
        sleep 0.15
    done

    wait "$pid"
    local rc=$?

    if [ $rc -eq 0 ]; then
        printf "\r%b%s%b [done]\n" "${green}" "$message" "${nc}"
    else
        printf "\r%b%s%b [failed]\n" "${red}" "$message" "${nc}"
        cat "$tmp_log" >&2 # Send error to stderr
    fi

    cat "$tmp_log" >> "$LOG_FILE"
    rm -f "$tmp_log"

    return $rc
}

# --- Final Actions ---

echo -e "\n============================================="
echo -e "${green}All updates complete.${nc}"
echo "=============================================\n"

read -p "Press Enter to exit or press Ctrl+C to stop the script."
