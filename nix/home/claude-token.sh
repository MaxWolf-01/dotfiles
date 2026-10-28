#!/usr/bin/env bash
# Claude Code on an account's setup-token; nix/home/claude-token.nix installs it
# as the `claude` on PATH, in front of the real binary.
# Usage: claude-token.sh <sops> <this wrapper's path> <profile|switch> [claude arguments...]
#
# Which account's token claude gets depends on the mode the host installs:
#
#   profile  (pc) the account CLAUDE_CONFIG_DIR names: ~/.claude (or none) is
#            `personal`, ~/.claude-<name> is <name>. An account with no file, or
#            a file whose token is empty (not minted yet), runs on whatever login
#            the profile holds.
#   switch   (zephylux) none: each profile runs on its own /login, unless
#            `claude-account <name>` switched the laptop, which puts every profile
#            on that account's token. A switched account with no token stops
#            claude rather than start it on the profile's own login. A caller
#            with CLAUDE_ACCOUNT_SWITCH=ignore (the scheduled units) is never
#            switched.
#
# An account's token is CLAUDE_CODE_OAUTH_TOKEN in
# secrets/creds/env/claude-<account>.env, and reaches claude in that variable,
# with the account's name in CLAUDE_ACCOUNT, which claude's hooks inherit: the
# mx plugin's session-page hook names the session's account from it. Where
# claude gets no token, it runs on the profile's own login and gets no
# CLAUDE_ACCOUNT either. Both are dropped from the caller's environment first,
# so a session started from another account's shell never runs on, or is named
# for, that account.
#
# The real claude is the next one on PATH after this wrapper, and is exec'd,
# so it keeps the pid the caller started: tmux-save finds a session's pane by
# that pid.
set -u

sops=$1
self=$(readlink -f "$2")
mode=$3
shift 3

real=""
IFS=: read -ra dirs <<<"$PATH"
for dir in "${dirs[@]}"; do
    candidate=${dir:-.}/claude
    [ -x "$candidate" ] && [ ! -d "$candidate" ] || continue
    [ "$(readlink -f "$candidate")" = "$self" ] && continue
    # Another copy of this wrapper (a second Home Manager profile on PATH) would
    # exec this one back, forever.
    head -c 4096 "$candidate" | grep -aq claude-token.sh && continue
    real=$candidate
    break
done
if [ -z "$real" ]; then
    echo "claude: no claude on PATH behind this wrapper ($self); install Claude Code (claude.ai/install.sh)" >&2
    exit 127
fi

unset CLAUDE_CODE_OAUTH_TOKEN CLAUDE_ACCOUNT
account=""
switched=""
case $mode in
    profile)
        config=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
        config=${config%/}
        case $config in
            "$HOME/.claude") account=personal ;;
            "$HOME"/.claude-*) account=${config#"$HOME"/.claude-} ;;
        esac
        ;;
    switch)
        state=$HOME/.config/claude-account
        if [ "${CLAUDE_ACCOUNT_SWITCH:-}" != ignore ] && [ -f "$state" ]; then
            read -r account <"$state"
            switched=$account
        fi
        ;;
    *)
        echo "claude: unknown wrapper mode '$mode' (profile or switch; see $self)" >&2
        exit 2
        ;;
esac

file=$HOME/.dotfiles/secrets/creds/env/claude-$account.env
if [ -n "$account" ] && [ -f "$file" ]; then
    if ! plain=$("$sops" decrypt --input-type dotenv --output-type dotenv "$file"); then
        echo "claude: could not decrypt $file, so the $account account has no token (is the age key SOPS_AGE_KEY_FILE names, '${SOPS_AGE_KEY_FILE:-}', there?)" >&2
        exit 1
    fi
    token=$(sed -n 's/^CLAUDE_CODE_OAUTH_TOKEN=//p' <<<"$plain")
    [ -z "$token" ] || export CLAUDE_CODE_OAUTH_TOKEN=$token CLAUDE_ACCOUNT=$account
fi
if [ -n "$switched" ] && [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    echo "claude: \`claude-account\` switched this laptop to '$switched', which has no token in $file; \`claude-account off\` goes back to each profile's own login" >&2
    exit 1
fi

exec "$real" "$@"
