#!/bin/bash

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Check for internet connectivity
check_for_internet() {
    clear
    if ping -q -c 1 -W 1 google.com >/dev/null 2>&1; then
        :
    else
        echo "No internet connection. Unable to download dependencies."
        exit 1
    fi
}

install_pacman_packages() {
    # Install the missing packages if we don't have them
    arch_packages=("sed" "bluez" "bluez-utils" "git" "less" "base-devel" "dosfstools" "rust" "firefox" "telegram-desktop" "flatpak")
    echo "Installing pacman packages: ${arch_packages[*]}"

    if [[ -f /etc/arch-release ]]; then
        for package in "${arch_packages[@]}"; do
            if ! sudo pacman -Q "$package" >/dev/null 2>&1; then
                sudo pacman -Sy --noconfirm --needed "$package"
            else
                echo "$package is already installed."
            fi
        done
    else
        echo "Your distro is not supported!"
        exit 1
    fi
}

install_paru() {
    # Install paru AUR helper if not already installed
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
    PARU_PACKAGES=("gnome-shell-extensions" "gnome-shell-extension-appindicator" "vscodium-bin" "adw-gtk-theme")
    echo "Installing AUR packages: ${PARU_PACKAGES[*]}"

    for PACKAGE in "${PARU_PACKAGES[@]}"; do
        if ! paru -Q "$PACKAGE" >/dev/null 2>&1; then
            paru -S --noconfirm --needed "$PACKAGE"
        else
            echo "$PACKAGE is already installed."
        fi
    done
}

# Enable Bluetooth
enable_bluetooth() {
    if [ -f /etc/bluetooth/main.conf ]; then
        echo "Enabling Bluetooth..."
        sudo cp /etc/bluetooth/main.conf /etc/bluetooth/main.conf.backup
        if sudo sed -i 's/#AutoEnable=true/AutoEnable=true/' /etc/bluetooth/main.conf; then
            sudo systemctl start bluetooth.service
            sudo systemctl enable bluetooth.service
            echo "Bluetooth configuration successful."
        else
            echo "Failed to enable Bluetooth. Exiting script."
            exit 1
        fi
    else
        echo "Bluetooth configuration file not found. Exiting script."
        exit 1
    fi
}

# Enable bash color and 15 simultaneous downloads
configure_pacman() {
    if [ -f /etc/pacman.conf ]; then
        echo "Enabling bash colors and simultaneous downloads..."
        sudo cp /etc/pacman.conf /etc/pacman.conf.backup
        if sudo sed -i 's/#Color/Color/' /etc/pacman.conf && sudo sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 15/' /etc/pacman.conf; then
            echo "Bash color and ParallelDownloads enabled..."
        else
            echo "Failed to enable bash colors or ParallelDownloads. Exiting script."
            exit 1
        fi
    else
        echo "pacman.conf not found. Exiting script."
        exit 1
    fi
}

# Configure zram swap
configure_zram() {
    if [ -f /etc/systemd/zram-generator.conf ]; then
        echo "Enabling zram..."
        sudo cp /etc/systemd/zram-generator.conf /etc/systemd/zram-generator.conf.backup
        if sudo tee /etc/systemd/zram-generator.conf >/dev/null <<EOF
[zram0]
zram-size = ram
EOF
        then
            echo "zram configuration successful."
        else
            echo "Failed to configure zram. Exiting script."
            exit 1
        fi
    else
        echo "zram configuration file not found. Exiting script."
        exit 1
    fi
}

# Bash-it setup and theme change
install_bash_it() {
    rm -rf "$HOME/.bash_it"
    git clone --depth=1 https://github.com/Bash-it/bash-it.git "$TEMP_DIR/bash-it"
    mv "$TEMP_DIR/bash-it" ~/.bash_it
    ~/.bash_it/install.sh --silent -f
    rm -rf "$TEMP_DIR/bash-it"
    if sudo sed -i "s/^export BASH_IT_THEME=.*/export BASH_IT_THEME='zork'/" ~/.bashrc; then
        echo "Bash-it theme changed to 'zork'."
    else
        echo "Failed to change Bash-it theme."
        exit 1
    fi
}

tweak_gnome() {
    # Set git editor to nano
    git config --global core.editor "nano"

    # Fix folders opening in VSCodium instead of file manager
    xdg-mime default org.gnome.Nautilus.desktop inode/directory

    # Set custom keybinding for GNOME shell terminal (Ctrl+Alt+T)
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Console'
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'kgx'
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org.gnome.settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Primary><Alt>t'

    # Change theme to dark
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
}

# Main function
main() {
    check_for_internet
    install_pacman_packages
    install_paru
    install_aur_packages
    enable_bluetooth
    configure_pacman
    configure_zram
    install_bash_it
    tweak_gnome
}

# Call the main function
main

