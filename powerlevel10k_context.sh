#!/usr/bin/env bash

P10K_FILE="$HOME/.p10k.zsh"

if [[ ! -f "$P10K_FILE" ]]; then
    echo -e "${RED}[-] $P10K_FILE not found; skipping context tweaks.${NC}"
    exit 0
fi

echo -e "${BLUE}[*] Patching context settings in $P10K_FILE${NC}"

sed -E -i \
    's/^[[:space:]]*typeset -g (POWERLEVEL9K_CONTEXT_\{DEFAULT,SUDO\}_\{CONTENT,VISUAL_IDENTIFIER\}_EXPANSION=)/# \1/' \
    "$P10K_FILE"

sed -i \
    '/^[[:space:]]*typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS/,/^[[:space:]]*)/{
     /^[[:space:]]*context[[:space:]]*$/d
   }' \
    "$P10K_FILE"

sed -E -i \
    's/(RIGHT_PROMPT_ELEMENTS=\([^)]*?) context /\1 /' \
    "$P10K_FILE"

indent=$(grep -m1 'os_icon' "$P10K_FILE" | sed -E 's/^([[:space:]]*).*/\1/')

if [[ -n "$indent" ]]; then
    sed -i "/${indent}os_icon/a\\${indent}context" "$P10K_FILE"
else
    echo -e "${RED}[!] Could not detect os_icon indent; please verify your .p10k.zsh has an os_icon entry.${NC}"
fi

echo -e "${GREEN}[+] .p10k.zsh updated! Please run 'source ~/.p10k.zsh' to apply changes.${NC}"
