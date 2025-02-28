#!/bin/env bash

if [ "$EUID" -eq 0 ]; then
    HOME="/home/$SUDO_USER"
fi

DEPS="curl git zsh"
INSTALLED_DEPS=$(dpkg-query -W -f='${binary:Package}\n')
TO_BE_INSTALLED_DEPS=()

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

OMZSH_DIR=$HOME/.oh-my-zsh

if [ -d $OMZSH_DIR ]; then
    rm -rf $OMZSH_DIR
    rm $HOME/.zshrc
fi

echo "-y" | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
