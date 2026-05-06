#!/usr/bin/env bash

UTILS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[1;36m"
RESET="\033[0m"
NC="$RESET"

utils::refuse_root_user_install() {
    local install_mode="${1:-user}"

    if [[ "$install_mode" == "--system" ]]; then
        install_mode="system"
    fi

    if [[ "$install_mode" != "system" ]] && [[ "$EUID" -eq 0 ]]; then
        echo -e "${RED}[-] Refusing to run user install as root. Re-run without sudo, or use --system.${RESET}" >&2
        exit 1
    fi
}

utils::resolve_target_user() {
    if [[ "$EUID" -eq 0 ]]; then
        TARGET_USER="${SUDO_USER:-}"
        if [[ -z "$TARGET_USER" ]]; then
            return 1
        fi
        TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
        if [[ -z "$TARGET_HOME" ]]; then
            TARGET_HOME="/home/$TARGET_USER"
        fi
        AS_ROOT=true
    else
        TARGET_USER="$USER"
        TARGET_HOME="$HOME"
        AS_ROOT=false
    fi
}

utils::run_as_target() {
    local command="$1"
    if [[ "${AS_ROOT:-false}" == true ]]; then
        sudo -u "$TARGET_USER" HOME="$TARGET_HOME" bash -lc "$command"
    else
        HOME="$TARGET_HOME" bash -lc "$command"
    fi
}
