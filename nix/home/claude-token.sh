#!/usr/bin/env bash
# Claude Code on an account's setup-token; nix/home/claude-token.nix installs it
# as the `claude` on PATH, in front of the real binary.
# Usage: claude-token.sh <sops> <claude-accounts.sh> <this wrapper's path> <profile|switch> [claude arguments...]
#
# Which account's token claude gets depends on the mode the host installs, and on
# the account its profile (CLAUDE_CONFIG_DIR, or ~/.claude where none is set)
# belongs to, as claude-accounts.sh reads it:
#
#   profile  (pc) the profile's account. An account with no file, or a file
#            whose token is empty (not minted yet), runs on whatever login the
#            profile holds.
#   switch   (zephylux) none: each profile runs on its own /login, unless
#            `clawd use <account>` switched the personal profile, which puts it
#            on that account's token. No other profile is ever switched. A
#            switched account with no token stops claude rather than start it on
#            the profile's own login. A caller with CLAUDE_ACCOUNT_SWITCH=ignore
#            (the scheduled units) is never switched.
#
# The token reaches claude in CLAUDE_CODE_OAUTH_TOKEN, with the account's name in
# CLAUDE_ACCOUNT, which claude's hooks inherit: the mx plugin's session-page hook
# names the session's account from it. Where claude gets no token, it runs on the
# profile's own login and gets no CLAUDE_ACCOUNT either. Both are dropped from the
# caller's environment first, so a session started from another account's shell
# never runs on, or is named for, that account.
#
# The real claude is the next one on PATH after this wrapper, and is exec'd,
# so it keeps the pid the caller started: tmux-save finds a session's pane by
# that pid.
set -u

claude_sops=$1
claude_accounts_who=claude
. "$2"
self=$(readlink -f "$3")
mode=$4
shift 4

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
account=$(claude_profile_account "${CLAUDE_CONFIG_DIR:-$HOME/.claude}")
switched=""
case $mode in
    profile) ;;
    switch)
        if [ "$account" = personal ] && [ "${CLAUDE_ACCOUNT_SWITCH:-}" != ignore ]; then
            switched=$(claude_switched_account)
        fi
        account=$switched
        ;;
    *)
        echo "claude: unknown wrapper mode '$mode' (profile or switch; see $self)" >&2
        exit 2
        ;;
esac

if [ -n "$account" ]; then
    token=$(claude_account_token "$account")
    case $? in
        0) [ -z "$token" ] || export CLAUDE_CODE_OAUTH_TOKEN=$token CLAUDE_ACCOUNT=$account ;;
        1) exit 1 ;;
    esac
fi
if [ -n "$switched" ] && [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    echo "claude: \`clawd use\` switched the personal profile to '$switched', which has no token in $(claude_account_file "$switched"); \`clawd use personal\` goes back to its own login" >&2
    exit 1
fi

exec "$real" "$@"
