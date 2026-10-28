# shellcheck shell=bash
# The Claude accounts and profiles, sourced by the `claude` wrapper (claude-token.sh)
# and by bin/clawd, so both turn a profile into its account and an account into its
# token the same way.
#
# An account is a name with a credential file, secrets/creds/env/claude-<account>.env,
# whose CLAUDE_CODE_OAUTH_TOKEN is its setup-token, empty until one is minted. A profile
# is a Claude Code config dir: ~/.claude is the personal account's, ~/.claude-<account>
# that account's. Only the personal profile is ever switched to another account's token,
# by `clawd use`, which writes that account's name to claude_switch_file.
#
# The sourcer sets claude_accounts_who, the name its messages start with, and may set
# claude_sops to the sops binary to run. Bash alone: jarvis-sync runs `clawd quota` on a
# PATH without sed, grep or awk.

claude_creds_dir=$HOME/.dotfiles/secrets/creds/env
claude_switch_file=$HOME/.config/claude-account

claude_account_file() { printf '%s\n' "$claude_creds_dir/claude-$1.env"; }

# Every account with a credential file, one name a line.
claude_accounts() {
    local file
    for file in "$claude_creds_dir"/claude-*.env; do
        [ -f "$file" ] || continue
        file=${file##*/claude-}
        printf '%s\n' "${file%.env}"
    done
}

# claude_profile_account <config dir>: the account the profile belongs to; nothing for a
# config dir outside ~/.claude*.
claude_profile_account() {
    local dir=${1%/}
    case $dir in
        "$HOME/.claude") echo personal ;;
        "$HOME"/.claude-*) printf '%s\n' "${dir#"$HOME"/.claude-}" ;;
    esac
}

# Every profile on this machine: ~/.claude, and each ~/.claude-<name> that holds a login
# or names an account.
claude_profiles() {
    local dir
    echo "$HOME/.claude"
    for dir in "$HOME"/.claude-*/; do
        dir=${dir%/}
        [ -f "$dir/.credentials.json" ] || [ -f "$(claude_account_file "$(claude_profile_account "$dir")")" ] || continue
        printf '%s\n' "$dir"
    done
}

# claude_account_minted <account>: whether its file holds a token, read without
# decrypting: sops leaves an empty value as plain text.
claude_account_minted() {
    local line
    while IFS= read -r line; do
        [[ $line == CLAUDE_CODE_OAUTH_TOKEN=ENC\[* ]] && return 0
    done <"$(claude_account_file "$1")"
    return 1
} 2>/dev/null

# claude_account_token <account>: prints its token, empty where none is minted yet.
# Returns 3, printing nothing, where the account has no credential file, and 1, saying
# why on stderr, where the file does not decrypt. The one place a token is decrypted.
claude_account_token() {
    local file plain line
    file=$(claude_account_file "$1")
    [ -f "$file" ] || return 3
    if ! plain=$("${claude_sops:-sops}" decrypt --input-type dotenv --output-type dotenv "$file"); then
        echo "${claude_accounts_who:-claude}: could not decrypt $file, so the $1 account has no token (is the age key SOPS_AGE_KEY_FILE names, '${SOPS_AGE_KEY_FILE:-}', there?)" >&2
        return 1
    fi
    while IFS= read -r line; do
        [[ $line == CLAUDE_CODE_OAUTH_TOKEN=* ]] && printf '%s\n' "${line#*=}"
    done <<<"$plain"
    return 0
}

# The account `clawd use` put the personal profile on; nothing where it runs on its own
# login.
claude_switched_account() {
    local account=""
    [ -s "$claude_switch_file" ] && read -r account <"$claude_switch_file"
    [ "$account" = personal ] || printf '%s\n' "$account"
}
