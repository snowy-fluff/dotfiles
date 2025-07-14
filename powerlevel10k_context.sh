#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

P10K_FILE="$HOME/.p10k.zsh"
PATCH_FILE="$(dirname "$0")/p10k.patch"

if [[ ! -f "$P10K_FILE" ]]; then
    echo -e "${RED}Error: Powerlevel10k config file not found at '$P10K_FILE'.${NC}"
    exit 1
fi

if [[ ! -f "$PATCH_FILE" ]]; then
    echo -e "${RED}Error: Patch file not found at '$PATCH_FILE'.${NC}"
    exit 1
fi

echo -e "${BLUE}Applying patch to '$P10K_FILE'...${NC}"
patch --forward --ignore-whitespace "$P10K_FILE" < "$PATCH_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully patched '$P10K_FILE' using '$PATCH_FILE'.${NC}"
    echo -e "${GREEN}Please run 'source ~/.p10k.zsh' to apply the changes.${NC}"
else
    echo -e "${RED}Error: Failed to patch '$P10K_FILE'. A '.rej' file may have been created with the failed changes.${NC}"
    exit 1
fi
