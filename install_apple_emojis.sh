#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

echo -e "${BLUE}[+] Installing Apple Color Emoji font...${RESET}"

TMP_DIR="$(mktemp -d)"

FONT_URL="https://github.com/samuelngs/apple-emoji-linux/releases/latest/download/AppleColorEmoji.ttf"
USER_FONT_DIR="$HOME/.local/share/fonts"
SYSTEM_FONT_DIR="/usr/share/fonts/AppleColorEmoji"
FONT_NAME="AppleColorEmoji.ttf"

if [[ "${1:-}" == "--system" ]]; then
    INSTALL_DIR="$SYSTEM_FONT_DIR"
    SUDO="sudo"
    echo -e "${YELLOW}[+] System-wide install selected.${RESET}"
else
    INSTALL_DIR="$USER_FONT_DIR"
    SUDO=""
    echo -e "${YELLOW}[+] User install selected.${RESET}"
fi

echo -e "${BLUE}[+] Downloading Apple Color Emoji font...${RESET}"
curl -sSL "$FONT_URL" -o "$TMP_DIR/$FONT_NAME"

$SUDO mkdir -p "$INSTALL_DIR"

echo -e "${BLUE}[+] Installing fonts...${RESET}"
$SUDO mv "$TMP_DIR/$FONT_NAME" "$INSTALL_DIR/$FONT_NAME"
$SUDO chmod 644 "$INSTALL_DIR/$FONT_NAME"

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

rm -rf "$TMP_DIR"

if [[ "${1:-}" == "--system" ]]; then
    echo -e "${BLUE}[+] Updating system emoji priority...${RESET}"
    $SUDO cp "$GENERIC_CONF" "${GENERIC_CONF}.bak"
    $SUDO sed -i 's|<family>Noto Color Emoji</family>|<family>Apple Color Emoji</family>\n\t\t\t<family>Noto Color Emoji</family>|' "$GENERIC_CONF"
fi

echo -e "${BLUE}[+] Rebuilding font cache...${RESET}"
fc-cache -f -v

echo -e "${GREEN}[*] Installation complete!${RESET}"
