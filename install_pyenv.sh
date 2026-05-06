#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

echo -e "${BLUE}[+] Preparing pyenv installer...${NC}"

if ! utils::resolve_target_user; then
    if [[ "$EUID" -eq 0 ]]; then
        echo -e "${RED}[-] Refusing to run as root without an invoking user. Run the script as your user or with sudo from your account.${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}[*] Target user:${NC} ${TARGET_USER}"
echo -e "${YELLOW}[*] Target home:${NC} ${TARGET_HOME}"

DEPS=(build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
libsqlite3-dev curl git libncursesw5-dev xz-utils tk-dev \
libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev)

echo -e "${BLUE}[*] Checking for missing apt packages...${NC}"
TO_INSTALL=()
for pkg in "${DEPS[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        TO_INSTALL+=("$pkg")
    fi
done

if [ "${#TO_INSTALL[@]}" -gt 0 ]; then
    echo -e "${BLUE}[*] Installing packages:${NC} ${TO_INSTALL[*]}"
    if [[ "$AS_ROOT" == true ]]; then
        apt update
        apt install -y "${TO_INSTALL[@]}"
    else
        sudo apt update
        sudo apt install -y "${TO_INSTALL[@]}"
    fi
    echo -e "${GREEN}[+] Packages installed${NC}"
else
    echo -e "${GREEN}[+] All build dependencies already present${NC}"
fi

echo -e "${PURPLE}[*] Removing any existing pyenv at ${TARGET_HOME}/.pyenv (if present)${NC}"
if [[ -e "$TARGET_HOME/.pyenv" ]]; then
    if [[ "$AS_ROOT" == true ]]; then
        rm -rf "$TARGET_HOME/.pyenv"
    else
        rm -rf "$TARGET_HOME/.pyenv"
    fi
fi

echo -e "${PURPLE}[*] Installing pyenv via https://pyenv.run for ${TARGET_USER}${NC}"
if [[ "$AS_ROOT" == true ]]; then
    sudo -u "$TARGET_USER" bash -lc 'curl -fsSL https://pyenv.run | bash'
else
    bash -lc 'curl -fsSL https://pyenv.run | bash'
fi
echo -e "${GREEN}[+] pyenv installer finished${NC}"

if [[ "$AS_ROOT" == true ]]; then
    echo -e "${YELLOW}[*] Fixing ownership of ${TARGET_HOME}/.pyenv to ${TARGET_USER}${NC}"
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.pyenv" || true
fi

BASH_BLOCK=(
'export PYENV_ROOT="$HOME/.pyenv"'
'export PATH="$PYENV_ROOT/bin:$PATH"'
'eval "$(pyenv init --path)"'
'eval "$(pyenv init -)"'
)

ZSH_BLOCK=(
'export PYENV_ROOT="$HOME/.pyenv"'
'export PATH="$PYENV_ROOT/bin:$PATH"'
'eval "$(pyenv init -)"'
)

ensure_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        if [[ "$AS_ROOT" == true ]]; then
            sudo -u "$TARGET_USER" touch "$file"
            sudo chown "$TARGET_USER:$TARGET_USER" "$file"
        else
            touch "$file"
        fi
    fi
}

append_lines_if_missing() {
    local file="$1"; shift
    local -a lines=("$@")
    for line in "${lines[@]}"; do
        if [[ "$AS_ROOT" == true ]]; then
            if ! sudo -u "$TARGET_USER" grep -qxF "$line" "$file" 2>/dev/null; then
                sudo -u "$TARGET_USER" env APPEND_LINE="$line" APPEND_FILE="$file" bash -lc 'printf "%s\n" "$APPEND_LINE" >> "$APPEND_FILE"'
                echo -e "${GREEN}[+] Added to $(basename "$file"):${NC} $line"
            fi
        else
            if ! grep -qxF "$line" "$file" 2>/dev/null; then
                printf '%s\n' "$line" >> "$file"
                echo -e "${GREEN}[+] Added to $(basename "$file"):${NC} $line"
            fi
        fi
    done
}

ensure_file_exists "$TARGET_HOME/.profile"
ensure_file_exists "$TARGET_HOME/.bashrc"
ensure_file_exists "$TARGET_HOME/.bash_profile"
ensure_file_exists "$TARGET_HOME/.zprofile"
ensure_file_exists "$TARGET_HOME/.zshrc"

append_lines_if_missing "$TARGET_HOME/.profile" "${BASH_BLOCK[@]}"
append_lines_if_missing "$TARGET_HOME/.bashrc" "${BASH_BLOCK[@]}"
append_lines_if_missing "$TARGET_HOME/.bash_profile" "${BASH_BLOCK[@]}"
append_lines_if_missing "$TARGET_HOME/.zprofile" "${ZSH_BLOCK[@]}"
append_lines_if_missing "$TARGET_HOME/.zshrc" "${ZSH_BLOCK[@]}"

echo -e "${BLUE}[+] pyenv setup complete for ${TARGET_USER}${NC}"
echo -e "${BLUE}    Source with:${NC} ${YELLOW}source ~/.profile${NC} ${BLUE}or${NC} ${YELLOW}source ~/.bashrc${NC}"
echo -e "${BLUE}    Or restart your shell.${NC}"
