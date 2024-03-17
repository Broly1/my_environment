#!/bin/bash

# Check for internet connectivity
check_for_internet() {
	clear
	if ping -q -c 1 -W 1 google.com >/dev/null; then
		echo "We do have internet connection"
	else
		echo "No internet connection. Unable to download dependencies."
		exit 1
	fi
}

check_for_internet "$@"

# Install the missing packages if we don't have them

arch_packages=("bluez" "bluez-utils" "git" "less")

echo "Installing dependencies"

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

# Install yay (AUR helper)
echo "Installing yay..."
git clone https://aur.archlinux.org/yay.git
cd yay || exit
makepkg -si
cd ../

# Install yay extensions and programs
echo "yay Installing extensions and programs..."
if yay -S --noconfirm gnome-shell-extensions gnome-shell-extension-appindicator vscodium-bin; then
	echo "Extensions installed successfully."
else
	echo "Failed to install extensions. Please check yay for errors."
fi

# Enable Bluetooth
if [ -f /etc/bluetooth/main.conf ]; then
	echo "Enabling Bluetooth..."
	sudo cp /etc/bluetooth/main.conf /etc/bluetooth/main.conf.bak
	if sudo sed -i 's/#AutoEnable=true/AutoEnable=true/' /etc/bluetooth/main.conf; then
		sudo systemctl start bluetooth.service
		sudo systemctl enable bluetooth.service
	else
		echo "Failed to enable Bluetooth. Exiting script."
		exit 1
	fi
else
	echo "Bluetooth configuration file not found. Exiting script."
	exit 1
fi

# Set git editor to nano
git config --global core.editor "nano"

# Configure zram swap
if [ -f /etc/systemd/zram-generator.conf ]; then
	echo "Configuring zram..."
	sudo cp /etc/systemd/zram-generator.conf /etc/systemd/zram-generator.conf.bak
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

# Set custom keybinding for gnome shell terminal (Ctrl+Alt+T)
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Console'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'kgx'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Primary><Alt>t'

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
		;;
	*)
		echo "Skipping Android environment setup."
		;;
esac
