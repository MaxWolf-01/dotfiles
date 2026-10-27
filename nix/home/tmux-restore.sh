#!/usr/bin/env bash
# Restore the last tmux save, its Claude Code sessions resumed, unless a server runs.
# Usage: tmux-restore.sh <real-tmux-binary> <resurrect-dir> <columns> <lines>
set -u
tmux=$1 dir=$2 cols=$3 lines=$4
last=$dir/last

"$tmux" list-sessions &>/dev/null && exit 0

# Power loss can leave `last` naming a save that was never flushed (0 bytes).
if [ ! -s "$last" ]; then
    for f in $(ls -t "$dir"/tmux_resurrect_*.txt 2>/dev/null); do
        [ -s "$f" ] || continue
        ln -sfn "${f##*/}" "$last"
        ts=${f##*/tmux_resurrect_}
        ts=${ts%.txt}
        # A link, not a copy: tmux-save hardlinks the two, and cp refuses one file under two names.
        [ -s "$dir/pane_contents_$ts.tar.gz" ] && ln -f "$dir/pane_contents_$ts.tar.gz" "$dir/pane_contents.tar.gz"
        echo "tmux-restore: 'last' save was empty/missing, restored from $ts" >&2
        break
    done
fi
[ -s "$last" ] || exit 0
# The save this restore types its resumes from, which a save a minute on no longer holds where a resume failed:
# tmux-resume-restored.sh types them again from it.
ln -sfn "$(readlink "$last")" "$dir/restored"

# Session "0" exists only during restore; the save skips while it is present.
"$tmux" new-session -d -s 0 -x "$cols" -y "$lines"
restore_script=$("$tmux" show-options -gqv @resurrect-restore-script-path 2>/dev/null)
[ -x "$restore_script" ] && "$tmux" run-shell -t 0:0.0 "$restore_script"
