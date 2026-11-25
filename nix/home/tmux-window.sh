#!/usr/bin/env bash
# What every Ghostty window runs (nix/home/ghostty.nix): attaches it to the lowest-numbered
# tmux session no client is attached to, else to a new session under the lowest free number.
# Sessions with other names are left to `tms` and prefix f. First runs the unlock, which asks for
# the keys a fresh boot lacks while the window is still outside tmux, then restores the last save
# when no server runs yet. When tmux hangs, fails to start or dies under the window, the window
# gets a plain $SHELL instead, outside tmux, with a red line saying what went wrong.
# `ghostty -e <command>` never runs this.
# Usage: tmux-window.sh <real-tmux> <tmux-restore> <unlock>
set -u
tmux=$1 restore=$2 unlock=$3
# A Ghostty opened from inside a tmux pane inherits TMUX, and tmux refuses to nest.
unset TMUX

fallback() {
    printf '\e[31mtmux-window: %s. This is a plain shell, outside tmux.\e[0m\n' "$1" >&2
    exec "${SHELL:-/bin/sh}"
}

# Exit 1 is "no server running"; 124 is the timeout, a server that holds its socket and never answers.
sessions() { timeout 3 "$tmux" list-sessions -F '#{session_attached} #{session_name}' 2>/dev/null; }

# Before the restore: a restored pane has its command typed into it, which a prompt in its shell
# would take as the answer. Ctrl-C at the prompt skips it, and must not close the window with it.
if [ -x "$unlock" ]; then
    trap : INT
    "$unlock"
    trap - INT
fi

list=$(sessions)
case $? in
    0) ;;
    124) fallback "the tmux server did not answer within 3 s" ;;
    # Started any other way, the server would come up empty and tmux-restore.sh would then skip the save for good.
    *) "$restore" "$(tput cols)" "$(tput lines)"
       list=$(sessions) ;;
esac

# "0" is the restore's own session (tmux-restore.sh), never a window's.
numbered=$(awk '$2 ~ /^[1-9][0-9]*$/' <<<"$list" | sort -k2n)
name=$(awk '$1 == 0 { print $2; exit }' <<<"$numbered")
if [ -z "$name" ]; then
    name=1
    while grep -qx "[0-9]* $name" <<<"$numbered"; do name=$((name + 1)); done
fi

# Closing the window hangs up this script with the client, so it never reaches the check below.
"$tmux" new-session -A -s "$name" || fallback "tmux exited with status $? (session $name)"
