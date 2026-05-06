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
    FONT_DIR="/usr/share/fonts/SFMonoNerd"
    echo -e "${YELLOW}[+] System-wide install selected.${NC}"
else
    FONT_DIR="$HOME/.fonts/SFMonoNerd"
    echo -e "${YELLOW}[+] User install selected.${NC}"
fi

echo -e "${BLUE}[+] Installing SF Mono Nerd Fonts...${NC}"

TMP_DIR="$(mktemp -d)"
mkdir -p "$FONT_DIR"

BASE_URL="https://raw.githubusercontent.com/fluffy-awoo/SF-Mono-Nerd-Font/master"
FILES=(
    "SFMono Bold Italic Nerd Font Complete.otf"
    "SFMono Bold Nerd Font Complete.otf"
    "SFMono Heavy Italic Nerd Font Complete.otf"
    "SFMono Heavy Nerd Font Complete.otf"
    "SFMono Light Italic Nerd Font Complete.otf"
    "SFMono Light Nerd Font Complete.otf"
    "SFMono Medium Italic Nerd Font Complete.otf"
    "SFMono Medium Nerd Font Complete.otf"
    "SFMono Regular Italic Nerd Font Complete.otf"
    "SFMono Regular Nerd Font Complete.otf"
    "SFMono Semibold Italic Nerd Font Complete.otf"
    "SFMono Semibold Nerd Font Complete.otf"
)

pids=()
files=()

for fname in "${FILES[@]}"; do
    files+=("$fname")
    tmp_dest="$TMP_DIR/$fname"
    url="${BASE_URL}/${fname// /%20}"
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
        echo -e "${GREEN}[+] $fname downloaded${NC}"
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

echo -e "${GREEN}[+] SF Mono Nerd Fonts installed and cache refreshed${NC}"
