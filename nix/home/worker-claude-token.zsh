# A dispatch worker user's Claude Code token: the setup-token of the account its record
# names, which `claude-token-push` writes to this file from zephylux. Read from .zshenv,
# so every claude an ssh command or a tmux pane starts gets it.
if [[ -r $HOME/.config/claude-token ]]; then
  export CLAUDE_CODE_OAUTH_TOKEN="$(<$HOME/.config/claude-token)"
fi
