#!/bin/bash

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

check_for_internet "$@"

# Install the missing packages if we don't have them
arch_packages=("bluez" "bluez-utils" "git" "less" "base-devel" "dosfstools" "rust" "chromium")
echo "Installing pacman pkgs: "${arch_packages[@]}""

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

# Install paru (AUR helper)
if ! sudo pacman -Q paru >/dev/null 2>&1; then
	echo "paru is not installed. Installing..."
	git clone https://aur.archlinux.org/paru.git
	cd paru || exit
	makepkg -si
	cd ../
	rm -rf paru/
else
	echo "paru is already installed."
fi

# Install aur packages
paru_packages=("gnome-shell-extensions" "gnome-shell-extension-appindicator" "vscodium-bin" "adw-gtk3")
echo "Installing aur pkgs: "${paru_packages[@]}""
for package in "${paru_packages[@]}"; do
	if ! paru -Q "$package" >/dev/null 2>&1; then
		paru -S --noconfirm --needed "$package"
	else
		echo "$package is already installed."
	fi
done

# Enable Bluetooth
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

# Enable bash color and 15 simultaneous Downloads
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

# Configure zram swap
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

# Enable appindicator extension
gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com

# Set git editor to nano
git config --global core.editor "nano"

# Fix folders opening in VSCodium instead of file manager.
xdg-mime default org.gnome.Nautilus.desktop inode/directory

# Set custom keybinding for gnome shell terminal (Ctrl+Alt+T)
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Console'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'kgx'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Primary><Alt>t'

# change theme to dark
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Android environment setup (optional)
echo "Setup Android environment? (y/N)"
read -r choice
case "$choice" in
	y|Y)
		check_for_internet "$@"
		echo "Setting up Android environment..."
		git clone https://github.com/akhilnarang/scripts
		cd scripts/ || exit
		bash setup/arch-manjaro.sh
		cd ../
		rm -rf scripts/
		;;
	*)
		echo "Skipping Android environment setup."
		;;
esac
