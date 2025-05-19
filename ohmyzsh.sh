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

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

if [ "$EUID" -eq 0 ]; then
    sudo chown -R $SUDO_USER:$SUDO_USER $OMZSH_DIR

    if [ -f $HOME/.zshrc ]; then
        sudo chown $SUDO_USER:$SUDO_USER $HOME/.zshrc
    fi
fi
