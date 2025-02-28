#!/bin/env bash

DEPS="git gnome-tweaks gnome-shell-extensions"
THEME_DEPS="sassc gnome-themes-extra gtk2-engines-murrine"
INSTALLED_DEPS=$(dpkg-query -W -f='${binary:Package}\n')
TO_BE_INSTALLED_DEPS=()

# Check if the package is already installed
for DEP in $DEPS $THEME_DEPS; do
    if ! echo "$INSTALLED_DEPS" | grep -qw "$DEP"; then
        TO_BE_INSTALLED_DEPS+=("$DEP")
    fi
done

if [ "$EUID" -ne 0 ] && [ -n "$TO_BE_INSTALLED_DEPS" ]; then
    echo "Cannot continue without root permission, missing dependencies detected."
    exit 1
fi

# Install missing packages
if [ ${#TO_BE_INSTALLED_DEPS[@]} -gt 0 ]; then
    sudo apt install "${TO_BE_INSTALLED_DEPS[@]}" -y
fi

# Icons destination directory
ICON_DEST_DIR="${HOME}/.icons"
[ "$EUID" -eq 0 ] && ICON_DEST_DIR="/usr/share/icons"

THEME_DEST_DIR="$HOME/.themes"
[ "$EUID" -eq 0 ] && THEME_DEST_DIR="/usr/share/themes"

if [ -d "Catppuccin-GTK-Theme" ]; then
    echo "Directory 'Catppuccin-GTK-Theme' already exists, skipping git clone."
else
    git clone https://github.com/0x-FFFFFF/Catppuccin-GTK-Theme.git
fi

echo "Installing theme to $THEME_DEST_DIR"
./Catppuccin-GTK-Theme/themes/install.sh "$@" > /dev/null 2>&1

echo "Copying icons to $ICON_DEST_DIR"
if [ "$EUID" -eq 0 ]; then
    sudo cp -ra ./Catppuccin-GTK-Theme/icons/* "$ICON_DEST_DIR"
else
    cp -ra ./Catppuccin-GTK-Theme/icons/* "$ICON_DEST_DIR"
fi

echo "Cleaning up"
rm -rf ./Catppuccin-GTK-Theme