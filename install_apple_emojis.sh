#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RED="\033[31m"
RESET="\033[0m"

GENERIC_CONF="/etc/fonts/conf.d/60-generic.conf"

echo -e "${BLUE}[+] Installing Apple Color Emoji font...${RESET}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

DEB_URL="https://github.com/samuelngs/apple-emoji-ttf/releases/latest/download/fonts-apple-color-emoji.deb"
USER_FONT_DIR="$HOME/.local/share/fonts"
SYSTEM_FONT_DIR="/usr/share/fonts/AppleColorEmoji"
FONT_NAME="AppleColorEmoji.ttf"
DEB_NAME="fonts-apple-color-emoji.deb"

if [[ "${1:-}" == "--system" ]]; then
    if [[ "$EUID" -ne 0 ]]; then
        exec sudo bash "$0" --system "${@:2}"
    fi
    INSTALL_DIR="$SYSTEM_FONT_DIR"
    SUDO=""
    echo -e "${YELLOW}[+] System-wide install selected.${RESET}"
else
    INSTALL_DIR="$USER_FONT_DIR"
    SUDO=""
    echo -e "${YELLOW}[+] User install selected.${RESET}"
fi

echo -e "${BLUE}[+] Downloading Apple Color Emoji font...${RESET}"
curl -fsSL "$DEB_URL" -o "$TMP_DIR/$DEB_NAME"

if [[ "${1:-}" == "--system" ]]; then
    if ! command -v apt-get >/dev/null 2>&1; then
        echo -e "${RED}[-] apt-get is required for --system installs.${RESET}"
        exit 1
    fi

    echo -e "${BLUE}[+] Installing package...${RESET}"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$TMP_DIR/$DEB_NAME"
else
    if ! command -v dpkg-deb >/dev/null 2>&1; then
        echo -e "${RED}[-] dpkg-deb is required for user installs from the .deb package.${RESET}"
        exit 1
    fi

    mkdir -p "$INSTALL_DIR"

    echo -e "${BLUE}[+] Extracting font from package...${RESET}"
    dpkg-deb -x "$TMP_DIR/$DEB_NAME" "$TMP_DIR/extracted"

    echo -e "${BLUE}[+] Installing fonts...${RESET}"
    mv -f "$TMP_DIR/extracted/usr/share/fonts/truetype/apple-color-emoji/$FONT_NAME" "$INSTALL_DIR/$FONT_NAME"
    chmod 644 "$INSTALL_DIR/$FONT_NAME"
fi

CONFIG_DIR="$HOME/.config/fontconfig"
CONFIG_FILE="$CONFIG_DIR/fonts.conf"

echo -e "${BLUE}[+] Updating fontconfig rules...${RESET}"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_FILE" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias>
    <family>serif</family>
    <prefer><family>Apple Color Emoji</family></prefer>
  </alias>
  <alias>
    <family>sans-serif</family>
    <prefer><family>Apple Color Emoji</family></prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer><family>Apple Color Emoji</family></prefer>
  </alias>
  <match target="pattern">
    <test qual="any" name="family"><string>Noto Color Emoji</string></test>
    <edit name="family" mode="assign" binding="same">
      <string>Apple Color Emoji</string>
    </edit>
  </match>
</fontconfig>
EOF

if [[ "${1:-}" == "--system" ]] && [[ -f "$GENERIC_CONF" ]]; then
    echo -e "${BLUE}[+] Updating system emoji priority...${RESET}"
    cp "$GENERIC_CONF" "${GENERIC_CONF}.bak"
    if ! grep -qF "<family>Apple Color Emoji</family>" "$GENERIC_CONF"; then
        sed -i '0,/<family>Noto Color Emoji<\/family>/s//<family>Apple Color Emoji<\/family>\
\t\t\t<family>Noto Color Emoji<\/family>/' "$GENERIC_CONF"
    fi
fi

echo -e "${BLUE}[+] Rebuilding font cache...${RESET}"
fc-cache -f -v

echo -e "${GREEN}[*] Installation complete!${RESET}"
