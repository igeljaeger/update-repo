#!/bin/bash

LOG_FILE="/tmp/updates.log"
green='\033[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
nc='\033[0m'

export PATH="$HOME/.local/bin:$HOME/.deno/bin:$PATH"

exec > >(tee -a "$LOG_FILE") 2>&1

is_fedora() {
    grep -qi "^ID=fedora" /etc/os-release 2>/dev/null
}

pkg_installed() {
    rpm -q "$1" >/dev/null 2>&1
}

install_brave_origin_beta() {
    if ! pkg_installed brave-origin-beta; then
        echo -e "${green}Installing Brave Origin Beta...${nc}"

        if ! pkg_installed dnf5-plugins; then
            sudo dnf install -y dnf5-plugins
        fi

        sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-beta.s3.brave.com/brave-browser-beta.repo
        sudo dnf install -y brave-origin-beta
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
        curl -fsSL https://deno.land/install.sh | sh
    fi
}

install_required_dnf_packages() {
    local packages=(
        kde-partitionmanager
        git-core
        unrar
        vim
        android-tools
        mpv
        fastfetch
        plasma-discover-flatpak
    )

    # syncplay is only available via COPR
    local copr_packages=(syncplay)
    local missing=()
    local missing_copr=()
    local pkg

    if ! pkg_installed steam && ! pkg_installed steam-devices; then
        packages+=(steam-devices)
    fi

    for pkg in "${packages[@]}"; do
        if ! pkg_installed "$pkg"; then
            missing+=("$pkg")
        fi
    done

    # Check COPR packages
    for pkg in "${copr_packages[@]}"; do
        if ! pkg_installed "$pkg"; then
            missing_copr+=("$pkg")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${green}Installing required DNF packages...${nc}"
        sudo dnf install -y "${missing[@]}"
    fi

    if [ ${#missing_copr[@]} -gt 0 ]; then
        echo -e "${green}Installing COPR packages...${nc}"
        for pkg in "${missing_copr[@]}"; do
            sudo dnf copr enable -y batmanfeynman/syncplay 2>/dev/null || true
            sudo dnf install -y "$pkg"
        done
    fi

    # Swap ffmpeg-free for full ffmpeg from RPM Fusion if needed
    if pkg_installed ffmpeg-free && ! pkg_installed ffmpeg; then
        echo -e "${green}Swapping ffmpeg-free for ffmpeg (RPM Fusion)...${nc}"
        sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
    fi
}

install_ani_cli() {
    if ! command -v ani-cli >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/ani-cli" ]; then
        echo -e "${green}Installing ani-cli...${nc}"
        mkdir -p "$HOME/.local/bin"
        curl -L https://github.com/pystardust/ani-cli/releases/latest/download/ani-cli -o "$HOME/.local/bin/ani-cli" \
            || curl -L https://raw.githubusercontent.com/pystardust/ani-cli/master/ani-cli -o "$HOME/.local/bin/ani-cli"
        chmod a+rx "$HOME/.local/bin/ani-cli"
    fi
}

if ! is_fedora; then
    echo -e "${red}Unsupported distribution. Exiting.${nc}"
    exit 1
fi

echo -e "${green}Detected Fedora system.${nc}"

# Enable RPM Fusion if not already available
if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
    echo -e "${green}Enabling RPM Fusion repositories...${nc}"
    sudo dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
fi

echo -e "${green}Updating DNF packages...${nc}"
sudo dnf upgrade --refresh -y
sudo dnf autoremove -y

install_brave_origin_beta
install_required_dnf_packages
install_yt_dlp
install_deno
install_ani_cli

if command -v flatpak >/dev/null 2>&1; then
    echo -e "${green}Updating Flatpaks...${nc}"

    if ! flatpak remotes --user --columns=name | grep -qxF flathub; then
        echo -e "${yellow}User Flathub not configured.${nc}"
        read -p "Add user Flathub repository now? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        fi
    fi

    flatpak update --user -y >/dev/null 2>&1
    flatpak uninstall --user --unused -y >/dev/null 2>&1
else
    echo -e "${yellow}Flatpak is not installed.${nc}"
    read -p "Install Flatpak now? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo dnf install -y flatpak
        echo -e "${green}Flatpak installed. Rerun to add user Flathub and update.${nc}"
    fi
fi

echo -e "${green}All updates complete.${nc}"

read -p "Shutdown now? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${yellow}Powering off...${nc}"
    sudo /sbin/shutdown -h now
fi

echo -e "${green}Update script finished.${nc}"
