#!/usr/bin/env bash

# Color palette
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Dependencies list
DEPS="build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
libsqlite3-dev curl git libncursesw5-dev xz-utils tk-dev \
libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev"

# Detect real HOME when run via sudo
if [ "$EUID" -eq 0 ]; then
    HOME="/home/$SUDO_USER"
    echo -e "${YELLOW}[*] Running as root; switching HOME to $HOME${NC}"
fi

# Check & install missing apt packages
echo -e "${BLUE}[*] Checking for missing packages...${NC}"
INSTALLED=$(dpkg-query -W -f='${binary:Package}\n')
TO_INSTALL=()
for pkg in $DEPS; do
    if ! grep -qw "$pkg" <<<"$INSTALLED"; then
        TO_INSTALL+=("$pkg")
    fi
done

if [ ${#TO_INSTALL[@]} -gt 0 ]; then
    echo -e "${BLUE}[*] Installing:${NC} ${TO_INSTALL[*]}"
    sudo apt update
    sudo apt install -y "${TO_INSTALL[@]}"
    echo -e "${GREEN}[+] Packages installed!${NC}"
else
    echo -e "${GREEN}[+] All build dependencies already present!${NC}"
fi

# Remove old pyenv & install fresh
echo -e "${PURPLE}[*] Removing any existing ~/.pyenv${NC}"
rm -rf "$HOME/.pyenv"

echo -e "${PURPLE}[*] Installing pyenv via https://pyenv.run${NC}"
if curl -fsSL https://pyenv.run | bash &>/dev/null; then
    echo -e "${GREEN}[+] pyenv installed!${NC}"
else
    echo -e "${RED}[-] pyenv installation failed.${NC}"
    exit 1
fi

# Fix ownership if sudo was used
if [ "$EUID" -ne 0 ] && [ ${#TO_INSTALL[@]} -gt 0 ]; then
    echo -e "${YELLOW}[*] Fixing ownership of ~/.pyenv to $SUDO_USER${NC}"
    sudo chown -R "$SUDO_USER:$SUDO_USER" "$HOME/.pyenv"
fi

# Define init blocks for Bash & Zsh
BASH_ENV=(
    'export PYENV_ROOT="$HOME/.pyenv"'
    '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"'
    'eval "$(pyenv init - bash)"'
)

ZSH_ENV=(
    'export PYENV_ROOT="$HOME/.pyenv"'
    '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"'
    'eval "$(pyenv init - zsh)"'
)

# Ensure Bash login profile exists
if [ ! -f "$HOME/.profile" ] && [ ! -f "$HOME/.bash_profile" ]; then
    touch "$HOME/.profile"
    echo -e "${YELLOW}[*] Created empty ~/.profile for Bash logins${NC}"
fi

# Map rc-files → their env blocks
declare -A SHELL_MAP=(
    ["$HOME/.bashrc"]="BASH_ENV"
    ["$HOME/.profile"]="BASH_ENV"
    ["$HOME/.bash_profile"]="BASH_ENV"
    ["$HOME/.zprofile"]="ZSH_ENV"
    ["$HOME/.zshrc"]="ZSH_ENV"
)

# Append missing lines to each rc-file
for rc in "${!SHELL_MAP[@]}"; do
    block="${SHELL_MAP[$rc]}"
    if [ -f "$rc" ]; then
        eval "lines=(\"\${${block}[@]}\")"
        for line in "${lines[@]}"; do
            if ! grep -qF "$line" "$rc"; then
                echo "$line" >>"$rc"
                echo -e "${GREEN}[+] Added to $(basename "$rc"):${NC} $line"
            fi
        done
    fi
done

echo -e "${BLUE}[+] Pyenv is ready! Please restart your shell or run:${NC}"
echo -e "    ${YELLOW}source ~/.bashrc${NC} or ${YELLOW}source ~/.zshrc${NC}"
