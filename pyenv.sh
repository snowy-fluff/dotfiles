#!/bin/env bash

DEPS="build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev curl git libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev"
INSTALLED_DEPS=$(dpkg-query -W -f='${binary:Package}\n')
TO_BE_INSTALLED_DEPS=()
HOME="/home/$SUDO_USER"

# Check if the package is already installed
for DEP in $DEPS; do
    if ! echo "$INSTALLED_DEPS" | grep -qw "$DEP"; then
        TO_BE_INSTALLED_DEPS+=("$DEP")
    fi
done

if [ "$EUID" -ne 0 ] && [ -n "$TO_BE_INSTALLED_DEPS" ]; then
    echo "Cannot continue without root permission, missing dependencies detected."
    exit 1
fi

# Install build dependencies
if [ ${#TO_BE_INSTALLED_DEPS[@]} -gt 0 ]; then
    sudo apt update
    sudo apt install "${TO_BE_INSTALLED_DEPS[@]}" -y
fi

if [ -d "$HOME/.pyenv" ]; then
    rm -rf "$HOME/.pyenv"
fi

curl -fsSL https://pyenv.run | bash

if [ ! -d "$HOME/.pyenv" ]; then
    echo "Failed to install pyenv, exiting."
    exit 1
fi

# Prepare pyenv environment variables to add
PYENV_ENV=(
    'export PYENV_ROOT="$HOME/.pyenv"'
    '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"'
    'eval "$(pyenv init --path)"'
)

FILES=("$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.zshrc")

# Create .profile if neither .profile nor .bash_profile exist
if [ ! -f "$HOME/.profile" ] && [ ! -f "$HOME/.bash_profile" ]; then
    touch "$HOME/.profile"
fi

# Add pyenv environment variables to the files
for FILE in "${FILES[@]}"; do
    if [ -f "$FILE" ]; then
        for LINE in "${PYENV_ENV[@]}"; do
            if ! grep -qF "$LINE" "$FILE"; then
                echo "$LINE" >> "$FILE"
            fi
        done
    fi
done
