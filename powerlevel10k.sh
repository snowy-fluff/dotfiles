#!/bin/env bash

if [ "$EUID" -eq 0 ]; then
    HOME="/home/$SUDO_USER"
fi

DEPS="curl git zsh"
INSTALLED_DEPS=$(dpkg-query -W -f='${binary:Package}\n')
TO_BE_INSTALLED_DEPS=()

# Check if the package is already installed
for DEP in $DEPS; do
    if ! echo "$INSTALLED_DEPS" | grep -qw "$DEP"; then
        TO_BE_INSTALLED_DEPS+=("$DEP")
    fi
done

if [ "$EUID" -ne 0 ] && [ -n "$TO_BE_INSTALLED_DEPS" ]; then
    echo "Cannot continue without root permission, missing dependencies detected."
    exit 1
fi

# Install build dependencies
if [ ${#TO_BE_INSTALLED_DEPS[@]} -gt 0 ]; then
    sudo apt update
    sudo apt install "${TO_BE_INSTALLED_DEPS[@]}" -y
fi

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Please install oh-my-zsh first."
fi

if [ ! -f "$HOME/.zshrc" ]; then
    echo "Please initialize .zshrc first."
    exit 1
fi

P10K_DIR=$HOME/.oh-my-zsh/custom/themes/powerlevel10k

if [ -d $P10K_DIR ]; then
    rm -rf $P10K_DIR
fi

if [ "$EUID" -eq 0 ]; then
    sudo -u $SUDO_USER git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
else
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
fi

# Set theme to p10k in ~/.zshrc
sed -i -E 's/ZSH_THEME=".+"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' $HOME/.zshrc

URLS=(
    "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
    "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
    "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
    "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
)

if [ "$(id -u)" -eq 0 ]; then
    FONT_DIR="/usr/share/fonts"
    echo "Running as root. Installing fonts system-wide."
else
    FONT_DIR="$HOME/.fonts"
    echo "Running as non-root user. Installing fonts for the current user."
fi

for URL in "${URLS[@]}"; do
    FILENAME=$(basename "$URL" | sed 's/%20/ /g')
    echo "Downloading $FILENAME..."
    curl -fsSL "$URL" -o "$FILENAME"

    if [ $? -eq 0 ]; then
        echo "$FILENAME downloaded successfully."
    else
        echo "Failed to download $FILENAME."
    fi
done

echo "Refreshing font cache..."

if [ "$(id -u)" -eq 0 ]; then
    sudo mkdir -p "$FONT_DIR/truetype/MesloLGS"
    sudo mv *.ttf "$FONT_DIR/truetype/MesloLGS"
    sudo fc-cache -frv
else
    mkdir -p "$FONT_DIR/truetype/MesloLGS"
    mv *.ttf "$FONT_DIR/truetype/MesloLGS"
    fc-cache -frv
fi

echo "Fonts installed successfully."

exec $SHELL
