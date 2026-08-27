#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

echo -e "${BLUE}[+] Preparing pyenv installer...${NC}"

if ! utils::resolve_target_user; then
    echo -e "${RED}[-] Refusing to run as root without an invoking user. Run as your user or with sudo from your account.${NC}"
    exit 1
fi

echo -e "${YELLOW}[*] Target user:${NC} ${TARGET_USER}"
echo -e "${YELLOW}[*] Target home:${NC} ${TARGET_HOME}"

DEPS=(make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
libsqlite3-dev curl git libncursesw5-dev xz-utils tk-dev \
libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev libzstd-dev)

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

PYENV_DIR="$TARGET_HOME/.pyenv"
PYENV_BIN="$PYENV_DIR/bin/pyenv"

if [[ -e "$PYENV_DIR" ]]; then
    FOREIGN_OWNER="$(find "$PYENV_DIR" ! -user "$TARGET_USER" -print -quit 2>/dev/null || true)"
    if [[ -n "$FOREIGN_OWNER" ]]; then
        TARGET_GROUP="$(id -gn "$TARGET_USER")"
        echo -e "${RED}[-] ${PYENV_DIR} contains files not owned by ${TARGET_USER}.${NC}" >&2
        echo -e "${RED}    Review them, then repair ownership once with:${NC}" >&2
        echo -e "${YELLOW}    sudo chown -R '${TARGET_USER}:${TARGET_GROUP}' -- '${PYENV_DIR}'${NC}" >&2
        exit 1
    fi
fi

if [[ -x "$PYENV_BIN" ]]; then
    echo -e "${PURPLE}[*] Updating the existing pyenv installation for ${TARGET_USER}${NC}"
    if [[ -x "$PYENV_DIR/plugins/pyenv-update/bin/pyenv-update" ]]; then
        utils::run_as_target '"$HOME/.pyenv/bin/pyenv" update'
    else
        utils::run_as_target 'git -C "$HOME/.pyenv" pull --ff-only'
    fi
    echo -e "${GREEN}[+] pyenv update finished${NC}"
elif [[ -e "$PYENV_DIR" ]]; then
    echo -e "${RED}[-] ${PYENV_DIR} exists but does not contain an executable pyenv.${NC}" >&2
    echo -e "${RED}    Move it aside after reviewing its installed Python versions, then rerun this script.${NC}" >&2
    exit 1
else
    echo -e "${PURPLE}[*] Installing pyenv via https://pyenv.run for ${TARGET_USER}${NC}"
    utils::run_as_target 'curl -fsSL https://pyenv.run | bash'
    echo -e "${GREEN}[+] pyenv installer finished${NC}"
fi

if [[ ! -x "$PYENV_BIN" ]]; then
    echo -e "${RED}[-] pyenv installation verification failed: ${PYENV_BIN} is not executable.${NC}" >&2
    exit 1
fi

PYENV_VERSION="$(utils::run_as_target '"$HOME/.pyenv/bin/pyenv" --version')"
echo -e "${GREEN}[+] Verified ${PYENV_VERSION}${NC}"

ensure_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        utils::exec_as_target touch -- "$file"
    fi
}

configure_shell_file() {
    local file="$1"
    local shell_name="$2"
    local enable_virtualenv="${3:-false}"
    local line tmp_file last_index
    local -a preserved_lines=()

    ensure_file_exists "$file"
    tmp_file="$(utils::exec_as_target mktemp)"

    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            'export PYENV_ROOT="$HOME/.pyenv"' | \
            'export PATH="$PYENV_ROOT/bin:$PATH"' | \
            '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' | \
            'eval "$(pyenv init --path)"' | \
            'eval "$(pyenv init -)"' | \
            'eval "$(pyenv init - bash)"' | \
            'eval "$(pyenv init - zsh)"' | \
            'eval "$(pyenv virtualenv-init -)"')
                continue
            ;;
        esac
        preserved_lines+=("$line")
    done < "$file"

    while (( ${#preserved_lines[@]} > 0 )); do
        last_index=$(( ${#preserved_lines[@]} - 1 ))
        [[ -z "${preserved_lines[$last_index]}" ]] || break
        unset "preserved_lines[$last_index]"
    done

    if (( ${#preserved_lines[@]} > 0 )); then
        printf '%s\n' "${preserved_lines[@]}" >> "$tmp_file"
        printf '\n' >> "$tmp_file"
    fi
    printf '%s\n' \
        'export PYENV_ROOT="$HOME/.pyenv"' \
        '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' \
        "eval \"\$(pyenv init - $shell_name)\"" >> "$tmp_file"
    if [[ "$enable_virtualenv" == true ]]; then
        printf '%s\n' 'eval "$(pyenv virtualenv-init -)"' >> "$tmp_file"
    fi

    if ! utils::exec_as_target cp -- "$tmp_file" "$file"; then
        utils::exec_as_target rm -f -- "$tmp_file"
        return 1
    fi
    utils::exec_as_target rm -f -- "$tmp_file"
    echo -e "${GREEN}[+] Updated $(basename "$file") for ${shell_name}${NC}"
}

TARGET_SHELL="$(getent passwd "$TARGET_USER" | cut -d: -f7)"
SHELL_NAME="${TARGET_SHELL##*/}"
ENABLE_VIRTUALENV=false
if [[ -x "$PYENV_DIR/plugins/pyenv-virtualenv/bin/pyenv-virtualenv" ]]; then
    ENABLE_VIRTUALENV=true
fi

case "$SHELL_NAME" in
    bash)
        BASH_PROFILE="$TARGET_HOME/.profile"
        for candidate in .bash_profile .bash_login .profile; do
            if [[ -f "$TARGET_HOME/$candidate" ]]; then
                BASH_PROFILE="$TARGET_HOME/$candidate"
                break
            fi
        done
        configure_shell_file "$TARGET_HOME/.bashrc" bash "$ENABLE_VIRTUALENV"
        configure_shell_file "$BASH_PROFILE" bash false
    ;;
    zsh)
        configure_shell_file "$TARGET_HOME/.zshrc" zsh "$ENABLE_VIRTUALENV"
        configure_shell_file "$TARGET_HOME/.zprofile" zsh false
    ;;
    *)
        echo -e "${YELLOW}[*] Unsupported login shell '${SHELL_NAME:-unknown}'; shell startup files were not changed.${NC}"
        echo -e "${YELLOW}    Configure it with: ${PYENV_BIN} init --install${NC}"
    ;;
esac

echo -e "${BLUE}[+] pyenv setup complete for ${TARGET_USER}${NC}"
echo -e "${BLUE}    Restart with:${NC} ${YELLOW}exec \"\$SHELL\"${NC}"
