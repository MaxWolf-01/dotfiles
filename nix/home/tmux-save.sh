#!/usr/bin/env bash
# Save every tmux session in tmux-resurrect's format, for resurrect's own
# restore.sh (and `tms`, which runs it) to bring back unchanged.
#
# Usage: tmux-save.sh <real-tmux-binary> <resurrect-dir>
#
# Replaces resurrect's save.sh, which costs ~6 s of CPU a save: it starts ~1,800
# processes, a handful of tmux clients and a ps per pane, where this starts
# about ten whatever the pane count. It also re-captures only the panes whose
# window has had output since the previous save. tmux stamps window_activity on
# every byte a pane emits, so a pane is skipped only when its window has been
# silent since the second the previous save started and its size, cursor,
# history and pane id are unchanged. Unchanged pane files stay in save/ between
# saves, and the archive is rebuilt only when a pane file changed or went away.
#
# Each new archive is renamed into place, never written through, and hardlinked
# as pane_contents_<time>.tar.gz beside the state file of the same time. Every
# writer of the archive has to do the same, or it rewrites the history copy.
#
# Where the output deliberately differs from save.sh's:
# - a pane's full command comes from one `ps` for all panes, matched on the
#   exact parent pid, first child only; save.sh greps a pid prefix, which can
#   pick an unrelated process and write several lines into the state file.
# - a pane path keeps runs of spaces; save.sh word-splits it. Both escape only
#   the first space.
# - resurrect's save hooks are not run, and its old-save pruning is left to the
#   caller.
set -u
shopt -s extglob

tmux=$1
dir=$2
d=$'\t'
u=$'\x1f'  # field separator for tmux formats: tab is IFS whitespace and would collapse empty fields
printf -v ts '%(%Y%m%dT%H%M%S)T' -1
started=$EPOCHSECONDS
state=$dir/tmux_resurrect_$ts.txt
stage=$dir/save/pane_contents
fingerprints=$dir/save/fingerprints
cmds=$dir/save/commands.tmux
mkdir -p "$stage"

# tq <var> <string>: <var> = <string> quoted for a tmux command file (single
# quotes, each ' closed, escaped, reopened). Into a variable, since $(…) forks.
tq() { printf -v "$1" "'%s'" "${2//\'/\'\\\'\'}"; }
target='' file=''

# A pane's full command: the first process whose parent is the pane's shell.
declare -A fullcmd=()
while read -r ppid args; do
    [[ -v fullcmd[$ppid] ]] || fullcmd[$ppid]=$args
done < <(ps -a -o ppid= -o args=)

# Grouped sessions: the first session of a group is the original and is saved
# like any other; each later one becomes a grouped_session line pointing at it.
grouped=$d
grouped_lines=()
group_now=""
original=""
while IFS=$u read -r is_grouped group _ name; do
    [ "$is_grouped" = 1 ] || continue
    if [ "$group" != "$group_now" ]; then
        original=$name group_now=$group
        continue
    fi
    active="" alternate=""
    while read -r flags idx; do
        [[ $flags == *'*'* ]] && active=$idx
        [[ $flags == *'-'* ]] && alternate=$idx
    done < <("$tmux" list-windows -t "$name" -F '#{window_flags} #{window_index}')
    grouped_lines+=("grouped_session${d}${name}${d}${original}${d}:${alternate}${d}:${active}")
    grouped+="$name$d"
done < <("$tmux" list-sessions -F "#{session_grouped}$u#{session_group}$u#{session_id}$u#{session_name}" | sort)
is_grouped() { [[ $grouped == *"$d$1$d"* ]]; }

# Panes: one list-panes carries both the state-file fields and the fingerprint.
pane_lines=()
pane_keys=()
declare -A fp=() hist_cy=()
while IFS=$u read -r sess win wact wflags pidx title path pact pcmd ppid hist hbytes cx cy pw ph activity alt pane_id; do
    is_grouped "$sess" && continue
    key="$sess:$win.$pidx"
    pane_keys+=("$key")
    fp[$key]="$pane_id $hist $hbytes $cx $cy $pw $ph $alt $activity"
    hist_cy[$key]="$hist $cy"
    path=${path/ /\\ }
    pane_lines+=("pane${d}${sess}${d}${win}${d}${wact}${d}:${wflags}${d}${pidx}${d}${title}${d}:${path}${d}${pact}${d}${pcmd}${d}:${fullcmd[$ppid]-}")
done < <("$tmux" list-panes -a -F "#{session_name}$u#{window_index}$u#{window_active}$u#{window_flags}$u#{pane_index}$u#{pane_title}$u#{pane_current_path}$u#{pane_active}$u#{pane_current_command}$u#{pane_pid}$u#{history_size}$u#{history_bytes}$u#{cursor_x}$u#{cursor_y}$u#{pane_width}$u#{pane_height}$u#{window_activity}$u#{alternate_on}$u#{pane_id}")

# Windows: one list-windows, and every window's own automatic-rename in one
# client call. Each window's answer is followed by a line holding one tab, so
# an unset option (no output) still has its place.
windows=()
while IFS= read -r line; do
    IFS=$u read -r sess _ <<<"$line"
    is_grouped "$sess" || windows+=("$line")
done < <("$tmux" list-windows -a -F "#{session_name}$u#{window_index}$u:#{window_name}$u#{window_active}$u:#{window_flags}$u#{window_layout}")
: >"$cmds"
for line in "${windows[@]}"; do
    IFS=$u read -r sess win _ <<<"$line"
    tq target "$sess:$win"
    printf "show-options -w -t %s -qv automatic-rename\ndisplay-message -p '%s'\n" "$target" "$d" >>"$cmds"
done
auto_rename=()
value=""
while IFS= read -r line; do
    if [ "$line" = "$d" ]; then auto_rename+=("${value:-:}") value=""; else value=$line; fi
done < <(((${#windows[@]})) && "$tmux" source-file "$cmds")
window_lines=()
for i in "${!windows[@]}"; do
    window_lines+=("window${d}${windows[i]//$u/$d}${d}${auto_rename[i]-:}")
done

state_line=$("$tmux" display-message -p "state${d}#{client_session}${d}#{client_last_session}")

{
    ((${#grouped_lines[@]})) && printf '%s\n' "${grouped_lines[@]}"
    printf '%s\n' "${pane_lines[@]}" "${window_lines[@]}" "$state_line"
} >"$state"
if cmp -s "$state" "$dir/last"; then
    rm "$state"
else
    ln -fs "${state##*/}" "$dir/last"
fi

# Pane contents. The fingerprints file holds the previous save's start time,
# then one line per pane: key, fingerprint, and "empty" for a pane without
# content (it has no file to show it was captured).
declare -A prev=() was_empty=()
prev_started=0
if [ -f "$fingerprints" ]; then
    {
        read -r prev_started
        while IFS=$d read -r key value mark; do
            prev[$key]=$value
            [ "$mark" = empty ] && was_empty[$key]=1
        done
    } <"$fingerprints"
fi

captured=()
declare -A empty=() had_file=()
: >"$cmds"
for key in "${pane_keys[@]}"; do
    if [ "${prev[$key]-}" = "${fp[$key]}" ] && [[ -f "$stage/pane-$key" || -v was_empty[$key] ]] \
        && ((${fp[$key]##* } < prev_started)); then
        [[ -v was_empty[$key] ]] && empty[$key]=1
        continue
    fi
    captured+=("$key")
    [ -f "$stage/pane-$key" ] && had_file[$key]=1
    tq target "$key"
    tq file "$stage/pane-$key"
    printf 'capture-pane -eJ -S - -t %s -b tmux-save\nsave-buffer -b tmux-save %s\ndelete-buffer -b tmux-save\n' \
        "$target" "$file" >>"$cmds"
done
((${#captured[@]})) && "$tmux" source-file "$cmds"

# Trim trailing empty lines as save.sh does, and drop the file of a pane with
# no content: save.sh keeps a pane only if it has history, its cursor is below
# the first line, or its screen has more than one non-empty line (counted here
# with colour codes stripped, since this capture keeps them). A pane holds up to
# 50,000 lines, so this works on an array of lines: a pattern trimmed off the
# end of one long string retries at every position and takes minutes.
dirty=0
for key in "${captured[@]}"; do
    f="$stage/pane-$key"
    lines=()
    [ -f "$f" ] && mapfile -t lines <"$f"
    last=$((${#lines[@]} - 1))
    while ((last >= 0)) && [ -z "${lines[last]}" ]; do last=$((last - 1)); done
    read -r hist cy <<<"${hist_cy[$key]}"
    if [ "$hist" -eq 0 ] && [ "$cy" -eq 0 ]; then
        nonempty=0
        for line in "${lines[@]:0:last+1}"; do
            line=${line//$'\e['*([0-9;:])m/}
            [ -n "$line" ] && nonempty=$((nonempty + 1))
        done
        if [ "$nonempty" -le 1 ]; then
            empty[$key]=1
            rm -f "$f"
            [[ -v had_file[$key] ]] && dirty=1
            continue
        fi
    fi
    printf '%s\n' "${lines[@]:0:last+1}" >"$f"
    dirty=1
done

# Files of panes that no longer exist.
declare -A live=()
for key in "${pane_keys[@]}"; do live[$key]=1; done
for f in "$stage"/pane-*; do
    [ -e "$f" ] || continue
    [[ -v live[${f#"$stage/pane-"}] ]] || { rm -f "$f"; dirty=1; }
done

{
    echo "$started"
    for key in "${pane_keys[@]}"; do
        printf '%s\t%s\t%s\n' "$key" "${fp[$key]}" "${empty[$key]+empty}"
    done
} >"$fingerprints"

if ((dirty)) || [ ! -f "$dir/pane_contents.tar.gz" ]; then
    tar cf - -C "$dir/save" ./pane_contents/ | gzip >"$dir/pane_contents.tar.gz.tmp"
    mv "$dir/pane_contents.tar.gz.tmp" "$dir/pane_contents.tar.gz"
    ln -f "$dir/pane_contents.tar.gz" "$dir/pane_contents_$ts.tar.gz"
fi
