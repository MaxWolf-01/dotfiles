#!/usr/bin/env bash
# ssh-sk-askpass: the SSH_ASKPASS of the YubiKey agent (sudo-touch.nix). While a
# key waits for a touch, ssh-agent runs it with its message as the only argument
# and SSH_ASKPASS_PROMPT=none, and sends it SIGTERM once the key has answered.
# For that long it keeps a notification up (`notify`) naming the host that
# asked, so a touch request max did not cause shows as such, with a button to
# the tmux pane the asking ssh runs in.
#
# One sudo asks many times: once per YubiKey in the agent, and again after each
# missed touch (sudo-touch.nix). Those asks share one notification, which goes
# $grace seconds after the last of them ends, or after the key's second wait
# when a touch was missed (below). With no YubiKey plugged in it shows nothing,
# since every ask fails at once.
#
# Which host asked: the agent's only clients are the ssh processes forwarding it,
# so the client on the other end of each connection to the agent's socket is
# followed to its TCP peer, and that address looked up in $SSH_SK_HOSTS
# ("address name" lines). A host it cannot place is named as unknown.

set -uo pipefail

message="${1:-Confirm user presence}"
sock="${SSH_SK_AGENT_SOCK:?the agent socket}"
state="${XDG_RUNTIME_DIR:?}/ssh-sk-askpass"
# The gap between two asks of one sudo is a round trip to the host; nothing
# says whether another ask follows, so this deadline decides that none does.
grace=2

# A FIDO key announces HID usage page 0xF1D0 at the start of its report
# descriptor. None plugged in: the signature fails at once, with nothing to touch.
fido_present() {
    local descriptor
    for descriptor in "${SSH_SK_HIDRAW:-/sys/class/hidraw}"/*/device/report_descriptor; do
        [ "$(od -An -tx1 -N3 "$descriptor" 2>/dev/null | tr -d ' \n')" = 06d0f1 ] && return 0
    done
    return 1
}
fido_present || exit 0

# The pids of the ssh processes connected to the agent: the agent's end of each
# connection names the client's end by inode, and only the client's end carries
# a process (ssh-agent is not dumpable, so ss cannot see its descriptors).
clients() {
    local peers
    peers=$(ss -xH src "$sock" | awk '{ print $8 }')
    [ -n "$peers" ] || return 0
    ss -xpH | awk -v peers="$peers" '
        BEGIN { split(peers, p, "\n"); for (i in p) want[p[i]] = 1 }
        $6 in want && match($0, /pid=[0-9]+/) { print substr($0, RSTART + 4, RLENGTH - 4) }'
}

hosts_asking() {
    local pid address name
    for pid in $(clients | sort -u); do
        address=$(ss -tnpH state established | awk -v pid="pid=$pid," 'index($0, pid) { print $4; exit }')
        address="${address%:*}"
        address="${address#[}"
        address="${address%]}"
        name=$(awk -v a="$address" '$1 == a { print $2; exit }' "${SSH_SK_HOSTS:-/dev/null}")
        echo "${name:-an unknown host${address:+ ($address)}}"
    done
}

# The tmux pane an asking ssh client runs in: the pane whose process is the
# client or one of its ancestors. The tmux on PATH is the one serving max's
# panes; a client outside tmux has none.
pane_of() { # <pid>
    local pid=$1 panes pane
    panes=$(tmux list-panes -a -F '#{pane_pid} #{pane_id}' 2>/dev/null) || return 0
    while [ "${pid:-0}" -gt 1 ]; do
        pane=$(awk -v p="$pid" '$1 == p { print $2; exit }' <<<"$panes")
        [ -n "$pane" ] && { echo "$pane"; return 0; }
        pid=$(awk '/^PPid:/ { print $2 }' "/proc/$pid/status" 2>/dev/null)
    done
}

hosts=$(hosts_asking | sort -u | paste -sd, - | sed 's/,/ or /g')
hosts="${hosts:-an unknown host}"
key="ssh-sk-${hosts//[^A-Za-z0-9._-]/_}"
# The asks of one burst share a notification. This file names the latest of
# them and the ssh-agent it came from; the lock keeps an ask starting and one
# ending apart.
owner="$state/$key"
mkdir -p "$state"

# Takes the notification down $grace seconds from now, or with `retry`, from
# the end of the signature ssh-agent tries next, unless another ask has come by
# then. ssh-agent waits for this script to exit before it goes on, so the wait
# runs apart from it.
withdraw_later() { # [retry]
    (
        # Nothing inherited stays open: not the lock this script may hold, nor
        # the copy of the pipe to ssh-agent that OpenSSH leaves open beside
        # stdout, on which ssh-agent waits for EOF before it goes on.
        for fd in /proc/"$BASHPID"/fd/*; do
            fd=${fd##*/}
            [ "$fd" -le 2 ] || eval "exec $fd>&-"
        done
        if [ "${1:-}" = retry ]; then
            helper=$(next_helper)
            [ -z "$helper" ] || waitpid "$helper" 2>/dev/null
        fi
        sleep "$grace"
        exec {lock}>"$owner.lock"
        flock "$lock"
        read -r latest _ 2>/dev/null <"$owner"
        [ "${latest:-}" = $$ ] || exit 0
        notify withdraw "$key"
        rm -f "$owner"
    ) </dev/null >/dev/null 2>&1 &
}

# The ssh-sk-helper ssh-agent starts for its next signature, within moments of
# this script's exit; the deadline is for an ssh-agent that starts none.
next_helper() {
    local pid
    for _ in $(seq 40); do
        pid=$(pgrep -P "$PPID" -x ssh-sk-helper) && { echo "$pid"; return; }
        sleep 0.05
    done
}

# A file left by an ssh-agent since restarted is no burst.
in_burst() {
    local agent
    read -r _ agent 2>/dev/null <"$owner"
    [ "${agent:-}" = "$PPID" ]
}
own() { echo "$$ $PPID" >"$owner"; }

exec {lock}>"$owner.lock"

# A touch the key waited for in vain makes it answer "operation denied", which
# ssh-agent reads as a PIN being needed: it runs this again, without
# SSH_ASKPASS_PROMPT, to ask for one. These keys have no PIN. Without an answer
# ssh-agent waits here, and so does every sudo behind it; exiting 1 gives it an
# empty PIN, with which it waits for a touch once more, in a new ssh-sk-helper,
# for as long as the key likes, before it fails. The notification stays up for
# that wait.
if [ "${SSH_ASKPASS_PROMPT:-}" != none ]; then
    flock "$lock"
    in_burst && own && withdraw_later retry
    exit 1
fi

end() {
    trap '' TERM INT HUP
    [ -z "${waiter:-}" ] || kill "$waiter" 2>/dev/null
    withdraw_later
    exit 0
}
# Set before the raise: ssh-agent's SIGTERM can come at any point, and bash
# runs the trap once the command in progress has returned.
trap end TERM INT HUP

# The first ask of a burst raises the notification, which outlives it, as long
# as ssh-agent lives, until withdraw_later takes it down. Later asks leave it
# be, up or dismissed.
flock "$lock"
in_burst
first=$?
# Owned before the raise, so that an end right after it takes it down.
own
if [ $first -ne 0 ]; then
    pane=''
    for pid in $(clients | sort -u); do
        pane=$(pane_of "$pid")
        [ -z "$pane" ] || break
    done
    notify raise "$key" --while "$PPID" ${pane:+--tmux "$pane"} "Touch a YubiKey for $hosts" "$message"
fi
flock -u "$lock"

# Until ssh-agent's SIGTERM, or ssh-agent itself going, whichever comes first.
waitpid "$PPID" 2>/dev/null &
waiter=$!
wait "$waiter"
end
