#!/usr/bin/env zsh
# Zoxide AutoCD Integration
# Allows jumping to directories by typing their name without 'z' prefix

# Only proceed if zoxide is available
if ! command -v zoxide &>/dev/null; then
    return 0
fi

# Intercept single-word commands and check if zoxide knows them
function zoxide_accept_line() {
    local cmd="${BUFFER}"
    
    # Only process single words (alphanumeric, underscore, hyphen)
    if [[ "$cmd" =~ ^[[:alnum:]_-]+$ ]]; then
        # Skip if it's an existing command/alias/function
        if ! command -v "$cmd" &>/dev/null; then
            # Check if zoxide has this directory
            if zoxide query "$cmd" &>/dev/null 2>&1; then
                BUFFER="z $cmd"
            fi
        fi
    fi
    
    # Execute the (possibly modified) command
    zle .accept-line
}

# Override the accept-line widget
zle -N accept-line zoxide_accept_line