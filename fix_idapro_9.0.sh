#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

DEPS=(
    libxcb-cursor0
    qtwayland5
)

if ! utils::resolve_target_user; then
    if [[ "$EUID" -eq 0 ]]; then
        echo -e "${YELLOW}[!] Running as root without sudo user context.${NC}"
        TARGET_HOME="$HOME"
        TARGET_USER="root"
        AS_ROOT=true
    fi
fi

echo -e "${BLUE}[*] Installing dependencies...${NC}"
if [[ "$AS_ROOT" == true ]]; then
    apt update
    apt install -y "${DEPS[@]}"
else
    sudo apt update
    sudo apt install -y "${DEPS[@]}"
fi
echo -e "${GREEN}[+] Installed dependencies: ${DEPS[*]}${NC}"

if [[ "${1:-}" != "--path" ]]; then
    echo -e "${YELLOW}[!] --path not provided; skipping PATH update.${NC}"
    exit 0
fi

LINE='export PATH="$PATH:$HOME/idapro-9.0"'
RC_FILES=("$TARGET_HOME/.zshrc" "$TARGET_HOME/.bashrc" "$TARGET_HOME/.profile")
added=0

for rc in "${RC_FILES[@]}"; do
    if [[ -f "$rc" ]]; then
        echo -e "${BLUE}[*] Checking $rc...${NC}"
        if ! grep -Fq "$LINE" "$rc"; then
            if [[ "$AS_ROOT" == true ]] && [[ -n "${SUDO_USER:-}" ]]; then
                sudo -u "$TARGET_USER" bash -lc "printf '\n# Added by %s on %s\n%s\n' \"$(basename "$0")\" \"$(date --iso-8601=seconds)\" '$LINE' >> '$rc'"
            else
                printf '\n# Added by %s on %s\n%s\n' "$(basename "$0")" "$(date --iso-8601=seconds)" "$LINE" >> "$rc"
            fi
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
