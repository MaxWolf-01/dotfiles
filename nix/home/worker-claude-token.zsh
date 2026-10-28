# A dispatch worker user's Claude Code token: the setup-token of the account its record
# names, and that account's name, which `clawd push` writes to these files from zephylux.
# Read from .zshenv, so every claude an ssh command or a tmux pane starts gets them; the
# mx plugin's session page names the session's account from CLAUDE_ACCOUNT.
if [[ -r $HOME/.config/claude-token ]]; then
  export CLAUDE_CODE_OAUTH_TOKEN="$(<$HOME/.config/claude-token)"
  if [[ -r $HOME/.config/claude-token-account ]]; then
    export CLAUDE_ACCOUNT="$(<$HOME/.config/claude-token-account)"
  fi
fi
