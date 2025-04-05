#!/bin/bash

log="my_env_log.txt"
banner() {

cat <<'EOF'


▀█▀ 　 █░░█ █▀▀ █▀▀ 　 
▒█░ 　 █░░█ ▀▀█ █▀▀ 　 
▄█▄ 　 ░▀▀▀ ▀▀▀ ▀▀▀ 　 

░█▀▀█ █▀▀█ █▀▀ █░░█ 　 
▒█▄▄█ █▄▄▀ █░░ █▀▀█ 　 
▒█░▒█ ▀░▀▀ ▀▀▀ ▀░░▀ 　 

█▀▀▄ ▀▀█▀▀ █░░░█ 
█▀▀▄ ░░█░░ █▄█▄█ 
▀▀▀░ ░░▀░░ ░▀░▀░

EOF
}

TEMP_DIR=$(mktemp -d)
trap 'rm -rf $TEMP_DIR' EXIT

# Check for internet connectivity
check_for_internet() {
    if ! ping -q -c 1 -W 1 google.com >/dev/null 2>&1; then
        echo "No internet connection. Unable to download dependencies."
        exit 1
    fi
}

# Install packages using pacman if not already installed
install_pacman_packages() {
    ARCH_PACKAGES=(
        "sed"
        "bluez"
        "bluez-utils"
        "telegram-desktop"
        "git"
        "less"
        "fastfetch"
        "base-devel"
        "dosfstools"
        "rust"
        "firefox"
        "spectacle"
        "gwenview"
        "kdeconnect"
        "kcalc"
        "flatpak"
        "gnome-disk-utility"
        "qbittorrent"
        "gimp"
        "plasma-workspace"
        "power-profiles-daemon"
    )

    clear
    banner "$@"

    if [[ -f /etc/arch-release ]]; then
        for PACKAGE in "${ARCH_PACKAGES[@]}"; do
            if ! pacman -Q "$PACKAGE" >/dev/null 2>&1; then
                echo "$PACKAGE is missing, installing..."
                sudo pacman -Sy --noconfirm --needed "$PACKAGE"
            else
                echo "$PACKAGE is already installed."
            fi
        done
    else
        echo "Your distro is not supported!"
        exit 1
    fi
}

# Install paru AUR helper if not already installed
install_paru() {
    if ! pacman -Q paru >/dev/null 2>&1; then
        echo "paru is not installed. Installing..."
        git clone https://aur.archlinux.org/paru-bin.git "$TEMP_DIR/paru-bin"
        cd "$TEMP_DIR/paru-bin" || exit
        makepkg -si --noconfirm
        cd - || exit  
        rm -rf "$TEMP_DIR/paru-bin"
    else
        echo "paru is already installed."
    fi
}

# Install AUR packages using paru
install_aur_packages() {
    PARU_PACKAGES=(
        "vscodium-bin"
    )

    for PACKAGE in "${PARU_PACKAGES[@]}"; do
        if ! paru -Q "$PACKAGE" >/dev/null 2>&1; then
            echo "$PACKAGE is not installed. Installing..."
            paru -S --noconfirm --needed "$PACKAGE"
        fi
    done
}

# Enable Bluetooth and auto-enable devices
enable_bluetooth() {
    sudo cp /etc/bluetooth/main.conf /etc/bluetooth/main.conf.backup || { echo "Failed to back up Bluetooth configuration."; exit 1; }
    sudo sed -i 's/#AutoEnable=true/AutoEnable=true/' /etc/bluetooth/main.conf || { echo "Failed to configure Bluetooth."; exit 1; }   
    sudo systemctl start bluetooth.service
    sudo systemctl enable bluetooth.service
    echo "Bluetooth configuration successful."
}

# Enable pacman color, ILoveCandy, and parallel downloads
configure_pacman() {
    sudo cp /etc/pacman.conf /etc/pacman.conf.backup || { echo "Failed to back up pacman.conf."; exit 1; }
    sudo sed -i 's/#Color/Color/' /etc/pacman.conf || { echo "Failed to enable Color."; exit 1; }
if ! grep -q "^ILoveCandy$" /etc/pacman.conf; then
    sudo sed -i '/^Color$/a ILoveCandy' /etc/pacman.conf || { echo "Failed to add ILoveCandy."; exit 1; }
else
    echo "ILoveCandy is already present in /etc/pacman.conf. Skipping addition."
fi
    sudo sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 15/' /etc/pacman.conf || { echo "Failed to enable ParallelDownloads."; exit 1; }

    echo "Pacman color, ILoveCandy, and parallel downloads enabled."
}

# Fix Breeze cursor theme
fix_breeze_cursor() {
    sudo cp /usr/share/icons/default/index.theme /usr/share/icons/default/index.theme.backup || { echo "Failed to back up index.theme."; exit 1; }
    sudo sed -i 's/Inherits=[^ ]*/Inherits=breeze_cursors/' /usr/share/icons/default/index.theme || { echo "Failed to configure index.theme."; exit 1; }
    echo "Fixed Adwaita mouse pointer on some apps and SDDM."
}

# Configure zram swap
configure_zram() {
    sudo cp /etc/systemd/zram-generator.conf /etc/systemd/zram-generator.conf.backup || { echo "Failed to back up zram configuration."; exit 1; }
    sudo tee /etc/systemd/zram-generator.conf >/dev/null <<EOF || { echo "Failed to configure zram."; exit 1; }
[zram0]
zram-size = ram
EOF
}

# Custom bash theme
install_bash_it() {
    clear
    banner "$@"
    custom_prompt='PS1='\''\[\e[38;2;22;160;133m\]\u@\h:\[\e[38;2;253;188;75m\]\w\[\e[38;2;22;160;133m\]\$\[\e[0m\] '\'

    if grep -Fxq "$custom_prompt" ~/.bashrc; then
        echo "Custom prompt already exists in ~/.bashrc."
    else
        sed -i '/^PS1=/d' ~/.bashrc
        echo "$custom_prompt" >> ~/.bashrc
        echo "Custom prompt applied."
    fi

    source ~/.bashrc
}

mod_my_plasma() {
    # Change look and feel
    CUST_CONF_DIR="plasma-config"

    lookandfeeltool -a org.kde.breezedark.desktop || { echo "Look and feel failed to change theme."; exit 1; }
    echo "Look and feel changed to breeze dark."

    systemctl --user restart plasma-plasmashell || { echo "Failed to restart Plasma shell."; exit 1; }
    echo "Plasma shell restarted successfully."

    # Set wallpaper and update SDDM theme
    if [ -d "$CUST_CONF_DIR/wallpaper/MyWallpapers" ]; then
        sudo cp -r "$CUST_CONF_DIR/wallpaper/MyWallpapers/" "/usr/share/wallpapers/" || { echo "Failed to copy wallpapers."; exit 1; }
    else
        echo "Directory $CUST_CONF_DIR/wallpaper/MyWallpapers does not exist."
        exit 1
    fi

    plasma-apply-wallpaperimage "/usr/share/wallpapers/MyWallpapers/Loop_Mac.png" || { echo "Failed to apply wallpaper."; exit 1; }
    echo "Wallpaper applied successfully."

    balooctl6 suspend || { echo "Failed to suspend baloo."; exit 1; }
    balooctl6 disable || { echo "Failed to disable baloo."; exit 1; }
    balooctl6 purge || { echo "Failed to purge baloo."; exit 1; }

    # Set Git editor to nano
    git config --global core.editor "nano" || { echo "Failed to set git editor to nano."; exit 1; }
    echo "git editor set to nano"
}

# Main script
main() {
    check_for_internet
    install_pacman_packages
    install_paru
    install_aur_packages
    enable_bluetooth
    configure_pacman
    fix_breeze_cursor
    configure_zram
    install_bash_it
    mod_my_plasma
}

main | tee "$log" 
