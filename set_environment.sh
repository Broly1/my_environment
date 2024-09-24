#!/bin/bash

# Check for internet connectivity
check_for_internet() {
    clear
    if ! ping -q -c 1 -W 1 google.com >/dev/null 2>&1; then
        echo "No internet connection. Unable to download dependencies."
        exit 1
    fi
}

# Install packages using pacman if not already installed
install_pacman_packages() {
    ARCH_PACKAGES=("bluez" "bluez-utils" "git" "less" "base-devel" "dosfstools" "rust" "firefox" \
                   "papirus-icon-theme" "spectacle" "gwenview" "kdeconnect" "kcalc" "packagekit-qt6" \
                   "flatpak" "gnome-disk-utility" "qbittorrent" "gimp" "plasma-workspace")

    echo "Installing pacman packages: ${ARCH_PACKAGES[*]}"

    if [[ -f /etc/arch-release ]]; then
        for PACKAGE in "${ARCH_PACKAGES[@]}"; do
            if ! pacman -Q "$PACKAGE" >/dev/null 2>&1; then
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

# Install yay AUR helper if not already installed
install_yay() {
    if ! pacman -Q yay >/dev/null 2>&1; then
        echo "yay is not installed. Installing..."
        YAY_DIR=$(mktemp -d)
        git clone https://aur.archlinux.org/yay.git "$YAY_DIR"
        cd "$YAY_DIR" || exit
        makepkg -si --noconfirm
        cd - || exit
        rm -rf "$YAY_DIR"
    else
        echo "yay is already installed."
    fi
}

# Install AUR packages using yay
install_aur_packages() {
    YAY_PACKAGES=("vscodium-bin" "papirus-folders" "ttf-jetbrains-mono")
    echo "Installing AUR packages: ${YAY_PACKAGES[*]}"

    for PACKAGE in "${YAY_PACKAGES[@]}"; do
        if ! yay -Q "$PACKAGE" >/dev/null 2>&1; then
            yay -S --noconfirm --needed "$PACKAGE"
        else
            echo "$PACKAGE is already installed."
        fi
    done

    papirus-folders -C breeze --theme Papirus-Dark
}

# Enable Bluetooth and auto-enable devices
enable_bluetooth() {
    if [[ -f /etc/bluetooth/main.conf ]]; then
        sudo cp /etc/bluetooth/main.conf /etc/bluetooth/main.conf.backup
        if sudo sed -i 's/#AutoEnable=true/AutoEnable=true/' /etc/bluetooth/main.conf; then
            sudo systemctl start bluetooth.service
            sudo systemctl enable bluetooth.service
            echo "Bluetooth configuration successful."
        else
            echo "Failed to configure Bluetooth."
            exit 1
        fi
    else
        echo "Bluetooth configuration file not found!"
        exit 1
    fi
}

# Enable pacman color and parallel downloads
configure_pacman() {
    if [[ -f /etc/pacman.conf ]]; then
        sudo cp /etc/pacman.conf /etc/pacman.conf.backup
        if sudo sed -i 's/#Color/Color/' /etc/pacman.conf && sudo sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 15/' /etc/pacman.conf; then
            echo "Pacman color and parallel downloads enabled."
        else
            echo "Failed to configure pacman."
            exit 1
        fi
    else
        echo "pacman.conf not found!"
        exit 1
    fi
}

# Configure zram swap
configure_zram() {
    if [[ -f /etc/systemd/zram-generator.conf ]]; then
        sudo cp /etc/systemd/zram-generator.conf /etc/systemd/zram-generator.conf.backup
        if sudo tee /etc/systemd/zram-generator.conf >/dev/null <<EOF
[zram0]
zram-size = ram
EOF
        then
            echo "Zram configuration successful."
        else
            echo "Failed to configure zram."
            exit 1
        fi
    else
        echo "Zram configuration file not found!"
        exit 1
    fi
}

# Set Git editor to nano
configure_git() {
    git config --global core.editor "nano"
}

# Bash-it setup and theme change
install_bash_it() {
    TEMP_DIR=$(mktemp -d)
    git clone --depth=1 https://github.com/Bash-it/bash-it.git "$TEMP_DIR/bash-it"
    mv "$TEMP_DIR/bash-it" ~/.bash_it
    rm -rf "$TEMP_DIR"
    ~/.bash_it/install.sh

    if sudo sed -i "s/^export BASH_IT_THEME=.*/export BASH_IT_THEME='zork'/" ~/.bashrc; then
        echo "Bash-it theme changed to 'zork'."
    else
        echo "Failed to change Bash-it theme."
        exit 1
    fi
}

# change theme to dark and icons to papirus dark
change_theme_and_icons() {
    lookandfeeltool -a org.kde.breezedark.desktop

if [[ -d "/usr/share/icons/Papirus-Dark" ]]; then
    /usr/lib/plasma-changeicons Papirus-Dark
    echo "Icon theme changed to Papirus-Dark."
else
    echo "Error: Icon theme 'Papirus-Dark' not found."
fi

}

# Install SDDM theme
install_sddm_theme() {
    SDDM_CONF="/usr/lib/sddm/sddm.conf.d/default.conf"
    DEST_CONF="/etc/sddm.conf"
    TMP_FILE="/tmp/sddm.conf.modified"

    if [ -f "$SDDM_CONF" ]; then
        echo "Enabling Breeze SDDM theme..."

        if [ ! -f "$DEST_CONF" ]; then
            sudo cp "$SDDM_CONF" "$DEST_CONF"
        fi

        if sudo sed 's/Current=.*/Current=breeze/' "$DEST_CONF" | sudo tee "$TMP_FILE" > /dev/null; then
            sudo mv "$TMP_FILE" "$DEST_CONF"
            echo "Breeze SDDM theme enabled..."
        else
            echo "Failed to enable Breeze SDDM theme. Exiting script."
            exit 1
        fi
    else
        echo "$SDDM_CONF not found. Exiting script."
        exit 1
    fi
}

# Optionally install android enviroment
setup_android_env() {
    echo "Setup Android environment? (y/N)"
    read -r CHOICE
    case "$CHOICE" in
        y|Y)
            check_for_internet
            echo "Setting up Android environment..."
            TEMP_DIR=$(mktemp -d)
            git clone https://github.com/akhilnarang/scripts "$TEMP_DIR/scripts"
            cd "$TEMP_DIR/scripts" || exit
            bash setup/arch-manjaro.sh
            cd - || exit
            rm -rf "$TEMP_DIR"
            ;;
        *)
            echo "Skipping Android environment setup."
            ;;
    esac
}

# Main script
main() {
    check_for_internet
    install_pacman_packages
    install_yay
    install_aur_packages
    enable_bluetooth
    configure_pacman
    configure_zram
    configure_git
    install_bash_it
    change_theme_and_icons
    install_sddm_theme
    setup_android_env
}

main
