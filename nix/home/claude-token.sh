#!/usr/bin/env bash
# Claude Code on its account's setup-token; nix/home/claude-token.nix installs
# it as the `claude` on PATH, in front of the real binary.
# Usage: claude-token.sh <sops> <this wrapper's path> [claude arguments...]
#
# The account is the one CLAUDE_CONFIG_DIR names: ~/.claude (or none) is
# `personal`, ~/.claude-<name> is <name>. Its token is CLAUDE_CODE_OAUTH_TOKEN
# in secrets/creds/env/claude-<account>.env, and reaches claude in that
# variable. A token inherited from the caller is dropped first, so a session
# started from another account's shell never runs on that account's token. An
# account with no file, or a file whose token is empty (not minted yet), runs
# on whatever login the profile holds.
#
# The real claude is the next one on PATH after this wrapper, and is exec'd,
# so it keeps the pid the caller started: tmux-save finds a session's pane by
# that pid.
set -u

sops=$1
self=$(readlink -f "$2")
shift 2

real=""
IFS=: read -ra dirs <<<"$PATH"
for dir in "${dirs[@]}"; do
    candidate=${dir:-.}/claude
    [ -x "$candidate" ] && [ ! -d "$candidate" ] || continue
    [ "$(readlink -f "$candidate")" = "$self" ] && continue
    real=$candidate
    break
done
if [ -z "$real" ]; then
    echo "claude: no claude on PATH behind this wrapper ($self); install Claude Code (claude.ai/install.sh)" >&2
    exit 127
fi

config=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
config=${config%/}
case $config in
    "$HOME/.claude") account=personal ;;
    "$HOME"/.claude-*) account=${config#"$HOME"/.claude-} ;;
    *) account="" ;;
esac

unset CLAUDE_CODE_OAUTH_TOKEN
file=$HOME/.dotfiles/secrets/creds/env/claude-$account.env
if [ -n "$account" ] && [ -f "$file" ]; then
    if ! plain=$("$sops" decrypt --input-type dotenv --output-type dotenv "$file"); then
        echo "claude: could not decrypt $file, so the $account account has no token (is SOPS_AGE_KEY_FILE=${SOPS_AGE_KEY_FILE:-} there?)" >&2
        exit 1
    fi
    token=$(sed -n 's/^CLAUDE_CODE_OAUTH_TOKEN=//p' <<<"$plain")
    [ -z "$token" ] || export CLAUDE_CODE_OAUTH_TOKEN=$token
fi

exec "$real" "$@"
