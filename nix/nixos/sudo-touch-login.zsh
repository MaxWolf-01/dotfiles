# A login from the laptop forwards its YubiKey agent, and sshd points SSH_AUTH_SOCK at it. That agent holds the
# YubiKeys' sk keys alone, so git and ssh from here would find no key in it and fall back to this host's key file and
# its passphrase. So: sudo reads the forwarded agent from ~/.ssh/sk-agent.sock (pam_rssh's ssh_agent_addr, in
# sudo-touch.nix), which each such login repoints, and SSH_AUTH_SOCK goes back to this host's own agent. A tmux
# started by an earlier login finds the agent through the same link. sshd puts a forwarded agent at
# ~/.ssh/agent/s.<random>.sshd.<pid>.<random>.
if [[ ${SSH_AUTH_SOCK:-} == $HOME/.ssh/agent/s.*.sshd.* && -S $SSH_AUTH_SOCK ]]; then
  ln -sfn "$SSH_AUTH_SOCK" "$HOME/.ssh/sk-agent.sock"
  [[ -S ${XDG_RUNTIME_DIR:-}/ssh-agent ]] && export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent
fi
