#!/bin/bash

TEMP_DIR=$(mktemp -d)
trap 'rm -rf $TEMP_DIR' EXIT

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
    ARCH_PACKAGES=("sed" "bluez" "bluez-utils" "telegram-desktop" "git" "less" "base-devel" "dosfstools" "rust" "firefox" \
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
    PARU_PACKAGES=("vscodium-bin" "papirus-folders")
    echo "Installing AUR packages: ${PARU_PACKAGES[*]}"

    for PACKAGE in "${PARU_PACKAGES[@]}"; do
        if ! paru -Q "$PACKAGE" >/dev/null 2>&1; then
            paru -S --noconfirm --needed "$PACKAGE"
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
    rm -rf "$HOME/.bash_it"
    git clone --depth=1 https://github.com/Bash-it/bash-it.git "$TEMP_DIR/bash-it"
    mv "$TEMP_DIR/bash-it" ~/.bash_it
    ~/.bash_it/install.sh --silent -f
    rm -rf "$TEMP_DIR"
    if sudo sed -i "s/^export BASH_IT_THEME=.*/export BASH_IT_THEME='zork'/" ~/.bashrc; then
        echo "Bash-it theme changed to 'zork'."
    else
        echo "Failed to change Bash-it theme."
        exit 1
    fi
}

mod_my_plasma() {
    ORIG_CONF_DIR="$HOME/.config"
    CUST_CONF_DIR="plasma-config"
    BACKUP_DIR="$HOME/.config/backup"
    ORIG_SDDM_THEME="/usr/share/sddm/themes/breeze"
    SDDM_CONF="/usr/lib/sddm/sddm.conf.d/default.conf"
    DEST_CONF="/etc/sddm.conf"
    TMP_FILE="/tmp/sddm.conf.modified"

    # Backup existing configuration files and install my custom ones
        mkdir -p "$BACKUP_DIR"
        FILES=("plasma-org.kde.plasma.desktop-appletsrc" "plasmashellrc" "kwinrc" "powerdevilrc" "kscreenlockerrc")

        for FILE in "${FILES[@]}"; do
            if [ -f "$ORIG_CONF_DIR/$FILE" ]; then
                echo "Backing up $FILE to $BACKUP_DIR/${FILE}.bak"
                cp "$ORIG_CONF_DIR/$FILE" "$BACKUP_DIR/$FILE.bak"
                rm -rf "$ORIG_CONF_DIR/$FILE"
            else
                echo "File $FILE does not exist in $ORIG_CONF_DIR, skipping backup."
            fi

            if [ -f "$CUST_CONF_DIR/$FILE" ]; then
                echo "Copying modified $FILE from $CUST_CONF_DIR to $ORIG_CONF_DIR"
                cp "$CUST_CONF_DIR/$FILE" "$ORIG_CONF_DIR/$FILE"
            else
                echo "Modified file $FILE not found in $CUST_CONF_DIR, skipping overwrite."
            fi
        done

    # Change look and feel
    if lookandfeeltool -a org.kde.breezedark.desktop; then
        echo "Look and feel changed to breeze dark."
    else
        echo "Look and feel failed to change theme."
        exit 1
    fi

    # Change icon theme
    if [[ -d "/usr/share/icons/Papirus-Dark" ]] && /usr/lib/plasma-changeicons Papirus-Dark; then
        echo "Icon theme changed to Papirus-Dark."
    else
        echo "Error: Icon theme 'Papirus-Dark' not found or failed to change."
        exit 1
    fi

    # Set wallpaper and update SDDM theme
    if [ -d "$CUST_CONF_DIR/wallpaper/Reef" ]; then
        sudo cp -r "$CUST_CONF_DIR/wallpaper/Reef/" "/usr/share/wallpapers/"
    else
        echo "Failed to copy wallpapers."
        exit 1
    fi

    if [ -d "$ORIG_SDDM_THEME" ]; then
        sudo cp -r "$CUST_CONF_DIR/theme.conf.user" "$ORIG_SDDM_THEME"
        sudo cp -r "$CUST_CONF_DIR/wallpaper/Reef/reef.png" "$ORIG_SDDM_THEME"
    else
        echo "SDDM theme directory not found."
        exit 1
    fi

    if [ -f "$SDDM_CONF" ]; then
        echo "Enabling Breeze SDDM theme..."
        [ ! -f "$DEST_CONF" ] && sudo cp "$SDDM_CONF" "$DEST_CONF"
        sudo cp "$DEST_CONF" "$TMP_FILE"

        if sudo sed -i 's/Current=.*/Current=breeze/; s/CursorTheme=.*/CursorTheme=breeze/' "$TMP_FILE"; then
            sudo mv "$TMP_FILE" "$DEST_CONF"
            echo "Breeze SDDM theme enabled..."
        else
            echo "Failed to modify the SDDM configuration. Exiting script."
            exit 1
        fi
    else
        echo "$SDDM_CONF not found. Exiting script."
        exit 1
    fi

    if plasma-apply-wallpaperimage "/usr/share/wallpapers/Reef/reef.png"; then
        echo "Wallpaper applied successfully."
    else
        echo "Failed to apply wallpaper."
        exit 1
    fi

    if systemctl --user restart plasma-plasmashell; then 
        echo "Plasma shell restarted successfully."
    else
        echo "Failed to restart Plasma shell."
        exit 1
    fi
}

# Main script
main() {
    check_for_internet
    install_pacman_packages
    install_paru
    install_aur_packages
    enable_bluetooth
    configure_pacman
    configure_zram
    configure_git
    install_bash_it
    mod_my_plasma
}

main
