#!/usr/bin/env bash

# Color palette
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect real HOME when run via sudo
if [ "$EUID" -eq 0 ]; then
    HOME="/home/$SUDO_USER"
    echo -e "${BLUE}[*] Running as root; HOME set to $HOME${NC}"
fi

# Required packages
DEPS=(curl git zsh)
MISSING=()

# Check for missing deps
for pkg in "${DEPS[@]}"; do
    if ! dpkg-query -W -f='${binary:Package}\n' "$pkg" &>/dev/null; then
        MISSING+=("$pkg")
    fi
done

# Install missing deps
if [ ${#MISSING[@]} -gt 0 ]; then
    echo -e "${BLUE}[*] Installing: ${MISSING[*]}${NC}"
    sudo apt update && sudo apt install -y "${MISSING[@]}"
    echo -e "${GREEN}[+] Packages installed${NC}"
else
    echo -e "${GREEN}[+] All dependencies present${NC}"
fi

# Verify oh-my-zsh
OMZ="$HOME/.oh-my-zsh"
if [ ! -d "$OMZ" ]; then
    echo -e "${RED}[-] Please install oh-my-zsh first.${NC}"
    exit 1
fi

# Verify .zshrc
ZSHRC="$HOME/.zshrc"
if [ ! -f "$ZSHRC" ]; then
    echo -e "${RED}[-] .zshrc not found; initialize it first.${NC}"
    exit 1
fi

# Clone/update Powerlevel10k
THEME_DIR="${ZSH_CUSTOM:-$OMZ/custom}/themes/powerlevel10k"
echo -e "${BLUE}[*] Installing Powerlevel10k to $THEME_DIR${NC}"

# Remove only if it exists
if [ -d "$THEME_DIR" ]; then
    echo -e "${YELLOW}[*] Found existing theme directory; removing it...${NC}"
    rm -rf "$THEME_DIR"
    echo -e "${GREEN}[+] Removed old theme directory${NC}"
else
    echo -e "${GREEN}[+] No existing theme directory to remove${NC}"
fi

if [ "$EUID" -eq 0 ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$THEME_DIR"
    sudo chown -R "$SUDO_USER:$SUDO_USER" "$THEME_DIR"
else
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$THEME_DIR"
fi
echo -e "${GREEN}[+] Powerlevel10k installed${NC}"

# Set theme in .zshrc
sed -i -E 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$ZSHRC"
echo -e "${GREEN}[+] .zshrc updated with Powerlevel10k theme${NC}"

if [ "$EUID" -eq 0 ]; then
    FONT_DIR="/usr/share/fonts/truetype/JetBrainsMonoNerd"
    sudo mkdir -p "$FONT_DIR"
    echo -e "${BLUE}[*] Installing JetBrainsMono Nerd Fonts system-wide to $FONT_DIR${NC}"
else
    FONT_DIR="$HOME/.fonts/JetBrainsMonoNerd"
    mkdir -p "$FONT_DIR"
    echo -e "${BLUE}[*] Installing JetBrainsMono Nerd Fonts to $FONT_DIR${NC}"
fi

# List of patched Nerd Font URLs (v3.3.0)
URLS=(
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/tags/v3.3.0/patched-fonts/JetBrainsMono/Ligatures/Thin/JetBrainsMonoNerdFont-Thin.ttf"
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/tags/v3.3.0/patched-fonts/JetBrainsMono/Ligatures/ExtraLight/JetBrainsMonoNerdFont-ExtraLight.ttf"
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/tags/v3.3.0/patched-fonts/JetBrainsMono/Ligatures/Light/JetBrainsMonoNerdFont-Light.ttf"
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/tags/v3.3.0/patched-fonts/JetBrainsMono/Ligatures/Regular/JetBrainsMonoNerdFont-Regular.ttf"
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/tags/v3.3.0/patched-fonts/JetBrainsMono/Ligatures/Medium/JetBrainsMonoNerdFont-Medium.ttf"
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/tags/v3.3.0/patched-fonts/JetBrainsMono/Ligatures/SemiBold/JetBrainsMonoNerdFont-SemiBold.ttf"
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/tags/v3.3.0/patched-fonts/JetBrainsMono/Ligatures/Bold/JetBrainsMonoNerdFont-Bold.ttf"
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/tags/v3.3.0/patched-fonts/JetBrainsMono/Ligatures/ExtraBold/JetBrainsMonoNerdFont-ExtraBold.ttf"
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/tags/v3.3.0/patched-fonts/JetBrainsMono/Ligatures/ThinItalic/JetBrainsMonoNerdFont-ThinItalic.ttf"
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/tags/v3.3.0/patched-fonts/JetBrainsMono/Ligatures/ExtraLightItalic/JetBrainsMonoNerdFont-ExtraLightItalic.ttf"
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/tags/v3.3.0/patched-fonts/JetBrainsMono/Ligatures/LightItalic/JetBrainsMonoNerdFont-LightItalic.ttf"
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/tags/v3.3.0/patched-fonts/JetBrainsMono/Ligatures/Italic/JetBrainsMonoNerdFont-Italic.ttf"
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/tags/v3.3.0/patched-fonts/JetBrainsMono/Ligatures/MediumItalic/JetBrainsMonoNerdFont-MediumItalic.ttf"
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/tags/v3.3.0/patched-fonts/JetBrainsMono/Ligatures/SemiBoldItalic/JetBrainsMonoNerdFont-SemiBoldItalic.ttf"
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/tags/v3.3.0/patched-fonts/JetBrainsMono/Ligatures/BoldItalic/JetBrainsMonoNerdFont-BoldItalic.ttf"
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/tags/v3.3.0/patched-fonts/JetBrainsMono/Ligatures/ExtraBoldItalic/JetBrainsMonoNerdFont-ExtraBoldItalic.ttf"
)

# Download & install the Nerd Font files
for url in "${URLS[@]}"; do
    fname="$(basename "$url")"
    dest="$FONT_DIR/$fname"
    echo -e "${BLUE}[*] Downloading $fname...${NC}"
    if curl -fsSL "$url" -o "$dest"; then
        echo -e "${GREEN}[+] $fname downloaded to $dest${NC}"
    else
        echo -e "${RED}[-] Failed to download $fname${NC}"
    fi
done

# Refresh font cache
echo -e "${BLUE}[*] Refreshing font cache...${NC}"
if [ "$EUID" -eq 0 ]; then
    sudo fc-cache -f
else
    fc-cache -f
fi
echo -e "${GREEN}[+] JetBrainsMono Nerd Fonts installed and cache refreshed${NC}"

echo -e "${GREEN}[+] Setup complete. Please restart your shell.${NC}"
