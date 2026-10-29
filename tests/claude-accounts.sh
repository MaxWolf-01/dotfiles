# shellcheck shell=bash
# Claude Code accounts under a scratch HOME, for the tests that start claude through
# nix/home/claude-token.sh or read a token's expiry. Sourced after HOME is set; needs sops
# and age.

claude_nix_home="$(cd "$(dirname "${BASH_SOURCE[0]}")/../nix/home" && pwd)"

# A throwaway age key, as SOPS_AGE_KEY_FILE.
accounts_key() {
    mkdir -p "$HOME"
    rm -f "$HOME/accounts-age-key.txt"
    age-keygen -o "$HOME/accounts-age-key.txt" 2>/dev/null
    export SOPS_AGE_KEY_FILE="$HOME/accounts-age-key.txt"
}

# account_token <account> <token> [valid until]: the account's creds/env/claude-<account>.env,
# encrypted to that key. An empty token is an account whose token is not minted yet.
account_token() {
    local file="$HOME/.dotfiles/secrets/creds/env/claude-$1.env"
    mkdir -p "$(dirname "$file")"
    printf 'CLAUDE_CODE_OAUTH_TOKEN=%s\nCLAUDE__VALID_UNTIL=%s\n' "$2" "${3-}" >"$file"
    sops encrypt --in-place --age "$(age-keygen -y "$SOPS_AGE_KEY_FILE")" "$file"
}

# install_claude_wrapper <dir> [profile|switch]: the wrapper as the `claude` in <dir>, and
# the mode bin/clawd reads, as nix/home/claude-token.nix installs them, in pc's mode unless
# named.
install_claude_wrapper() {
    mkdir -p "$1" "$HOME/.config/clawd"
    printf '#!/usr/bin/env bash\nexec bash %q %q %q "$0" %q "$@"\n' "$claude_nix_home/claude-token.sh" "$(command -v sops)" \
        "$claude_nix_home/claude-accounts.sh" "${2:-profile}" >"$1/claude"
    chmod +x "$1/claude"
    echo "${2:-profile}" >"$HOME/.config/clawd/wrapper-mode"
}
