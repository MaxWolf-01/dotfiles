#!/usr/bin/env bash
# ssh-sk-askpass: the SSH_ASKPASS of the YubiKey agent (sudo-touch.nix). While a
# key waits for a touch, ssh-agent runs it with its message as the only argument
# and SSH_ASKPASS_PROMPT=none, and sends it SIGTERM once the key has answered.
# For that long it keeps a waiting prompt in $XDG_RUNTIME_DIR/prompt-waits/,
# naming the host that asked, so a touch request max did not cause shows as such.
#
# Which host asked: the agent's only clients are the ssh processes forwarding it,
# so the client on the other end of each connection to the agent's socket is
# followed to its TCP peer, and that address looked up in $SSH_SK_HOSTS
# ("address name" lines). A host it cannot place is named as unknown.

set -uo pipefail

message="${1:-Confirm user presence}"
sock="${SSH_SK_AGENT_SOCK:?the agent socket}"
dir="${XDG_RUNTIME_DIR:?}/prompt-waits"
id="ssh-sk-agent-$$"
file="$dir/$id.json"

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

hosts=$(hosts_asking | sort -u | paste -sd, - | sed 's/,/ or /g')
hosts="${hosts:-an unknown host}"

mkdir -p "$dir"
cleanup() {
    rm -f "$file" "$dir/.$id.tmp"
    [ -z "${waiter:-}" ] || kill "$waiter" 2>/dev/null
    exit 0
}
trap cleanup TERM INT HUP

jq -n --arg id "$id" --arg prompt "$message" --arg host "$hosts" --arg since "$(date -u +%FT%TZ)" '{
    id: $id,
    kind: "touch",
    prompt: "Touch a YubiKey for \($host): \($prompt)",
    command: "\($host), through the forwarded YubiKey agent",
    pane: null,
    since: $since
}' >"$dir/.$id.tmp" && mv "$dir/.$id.tmp" "$file"

# Until ssh-agent's SIGTERM, or ssh-agent itself going, whichever comes first.
tail --pid="$PPID" -f /dev/null &
waiter=$!
wait "$waiter"
cleanup
