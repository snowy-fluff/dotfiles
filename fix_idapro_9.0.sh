#!/usr/bin/env bash
set -euo pipefail

RED="\033[0;31m";
GREEN="\033[0;32m";
YELLOW="\033[1;33m"
BLUE="\033[0;34m";
NC="\033[0m"

DEPS=(
    libxcb-cursor0
    qtwayland5
)

echo -e "${BLUE}[*] Installing dependencies...${NC}"
sudo apt update
sudo apt install -y "${DEPS[@]}"
echo -e "${GREEN}[+] Installed dependencies: ${DEPS[*]}${NC}"

if [[ "${1:-}" != "--path" ]]; then
    echo -e "${YELLOW}[!] --path not provided; skipping PATH update.${NC}"
    exit 0
fi

LINE='export PATH="$PATH:$HOME/idapro-9.0"'
RC_FILES=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile")
added=0

for rc in "${RC_FILES[@]}"; do
    if [[ -f "$rc" ]]; then
        echo -e "${BLUE}[*] Checking $rc...${NC}"
        if ! grep -Fq "$LINE" "$rc"; then
            printf '\n# Added by %s on %s\n%s\n' "$(basename "$0")" "$(date --iso-8601=seconds)" "$LINE" >> "$rc"
            echo -e "${GREEN}[+] Appended PATH to $rc${NC}"
            added=1
        else
            echo -e "${YELLOW}[*] PATH already present in $rc${NC}"
        fi
    else
        echo -e "${YELLOW}[-] $rc does not exist — skipping.${NC}"
    fi
done

if [[ $added -eq 0 ]]; then
    echo -e "${YELLOW}[!] No files were modified.${NC}"
else
    echo -e "${GREEN}[+] Done. Source the updated rc(s) or restart your shell.${NC}"
fi
