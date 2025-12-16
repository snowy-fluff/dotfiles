#!/usr/bin/env bash
set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

if [[ "${1:-}" == "--system" ]]; then
    if [[ "$EUID" -ne 0 ]]; then
        exec sudo bash "$0" --system "${@:2}"
    fi
    FONT_DIR="/usr/share/fonts/JetBrainsMonoNerd"
    echo -e "${YELLOW}[+] System-wide install selected.${NC}"
else
    FONT_DIR="$HOME/.fonts/JetBrainsMonoNerd"
    echo -e "${YELLOW}[+] User install selected.${NC}"
fi

echo -e "${BLUE}[+] Installing JetBrainsMono Nerd Fonts...${NC}"

TMP_DIR="$(mktemp -d)"
mkdir -p "$FONT_DIR"

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

pids=()
files=()

for url in "${URLS[@]}"; do
    fname="$(basename "$url")"
    files+=("$fname")
    tmp_dest="$TMP_DIR/$fname"
    echo -e "${BLUE}[*] Downloading $fname...${NC}"
    curl -fsSL "$url" -o "$tmp_dest" &
    pids+=("$!")
done

failed=0
for i in "${!pids[@]}"; do
    pid="${pids[$i]}"
    fname="${files[$i]}"
    if ! wait "$pid"; then
        echo -e "${RED}[-] Failed to download $fname${NC}"
        failed=1
        for kp in "${pids[@]}"; do
            if kill -0 "$kp" 2>/dev/null; then
                kill "$kp" 2>/dev/null || true
            fi
        done
        break
    else
        echo -e "${GREEN}[+] ${files[$i]} downloaded${NC}"
    fi
done

if [[ "$failed" -ne 0 ]]; then
    rm -rf "$TMP_DIR"
    echo -e "${RED}[-] One or more downloads failed. Exiting.${NC}"
    exit 1
fi

for fname in "${files[@]}"; do
    src="$TMP_DIR/$fname"
    dest="$FONT_DIR/$fname"
    echo -e "${BLUE}[*] Installing fonts...${NC}"
    mv -f "$src" "$dest"
    chmod 644 "$dest"
    echo -e "${GREEN}[+] $fname installed to $dest${NC}"
done

rm -rf "$TMP_DIR"

echo -e "${BLUE}[*] Refreshing font cache...${NC}"
fc-cache -f

echo -e "${GREEN}[+] JetBrainsMono Nerd Fonts installed and cache refreshed${NC}"
