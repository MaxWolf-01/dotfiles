# sudo by a YubiKey touch, the server half: pam_rssh asks the ssh agent max
# forwards from the laptop (nix/home/sudo-touch.nix) to sign with one of the
# YubiKeys' ed25519-sk keys. `sufficient`, ahead of the password: no agent, no
# key in it, or no touch, and sudo asks for the password as before.
{ ... }:
{
  security.pam.rssh = {
    enable = true;
    settings = {
      # Written here, so root-owned, and holding the sk keys alone: no file max
      # can write decides sudo. $ruser is the user who ran sudo.
      auth_key_file = "/etc/ssh/sudo-touch/$ruser";
      # The forwarded agent, as sudo-touch-login.zsh links it: SSH_AUTH_SOCK is
      # this host's own agent. A link max can write is no way in: whatever agent
      # it names still has to sign with a key auth_key_file lists.
      ssh_agent_addr = "/home/$ruser/.ssh/sk-agent.sock";
      cue = true;
    };
  };
  security.pam.services.sudo.rssh = true;
  programs.zsh.shellInit = builtins.readFile ./sudo-touch-login.zsh;

  environment.etc."ssh/sudo-touch/max".source = ../yubikey/sudo-sk-keys.pub;
}
