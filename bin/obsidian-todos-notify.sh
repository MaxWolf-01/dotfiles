#!/usr/bin/env bash

# Simple script to send today's + yesterday's unchecked Obsidian todos via ntfy

VAULT="$HOME/repos/obsidian/knowledge-base"
TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)

TODAY_NOTE="$VAULT/Obsidian/daily-notes/$TODAY.md"
YESTERDAY_NOTE="$VAULT/Obsidian/daily-notes/$YESTERDAY.md"

# Source secrets for notify function
source "$HOME/.dotfiles/secrets/zshrc" 2>/dev/null || source "$HOME/.dotfiles/secrets/bashrc"

MESSAGE=""

# Get yesterday's unchecked todos
if [ -f "$YESTERDAY_NOTE" ]; then
    YESTERDAY_TODOS=$(grep '^\s*- \[ \]' "$YESTERDAY_NOTE" | sed 's/^\s*- \[ \]/• /')
    if [ -n "$YESTERDAY_TODOS" ]; then
        MESSAGE="📅 From yesterday:\n$YESTERDAY_TODOS\n\n"
    fi
fi

# Get today's todos
if [ -f "$TODAY_NOTE" ]; then
    TODAY_TODOS=$(grep '^\s*- \[ \]' "$TODAY_NOTE" | sed 's/^\s*- \[ \]/• /')
    if [ -n "$TODAY_TODOS" ]; then
        MESSAGE="${MESSAGE}📆 Today:\n$TODAY_TODOS"
    fi
fi

# Check if we have any todos at all
if [ -z "$MESSAGE" ]; then
    MESSAGE="✅ No todos pending"
fi

# Send notification
notify "$MESSAGE" "📋 Todos $TODAY"
echo "Sent todos notification"