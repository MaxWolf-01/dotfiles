#!/usr/bin/env bash
# Resume the Claude Code sessions the last restore typed a resume for and that do not run: the save's command, typed
# again into the pane the restore made for it, where that pane is back at its shell.
# On pc the boot's restore runs before `hosts unlock pc` sends the age key, so every resume it types fails on the
# account's token; host-unlock-receive's finish runs this once the key is there. The record of the restore goes with
# the run, so a second unlock types nothing twice.
# Usage: tmux-resume-restored.sh <real-tmux-binary> <resurrect-dir>
set -u
tmux=$1 restored=$2/restored
[ -s "$restored" ] || exit 0

# A save's pane line, tab-separated: pane, session, window, its active flag, :its flags, pane, title, :path, its active
# flag, its command, :the command it was saved with. A title may be empty, which `read` would merge away.
while IFS=$'\t' read -r target cmd; do
    case $("$tmux" display -p -t "$target" '#{pane_current_command}' 2>/dev/null) in
        zsh | bash | sh)
            "$tmux" send-keys -t "$target" -l "${cmd#:}" && "$tmux" send-keys -t "$target" Enter &&
                echo "tmux-resume-restored: resumed ${cmd##*--resume } in $target"
            ;;
    esac
done < <(awk -F'\t' '$1 == "pane" && $NF ~ /claude --resume / { print $2 ":" $3 "." $6 "\t" $NF }' "$restored")
rm -f "$restored"
