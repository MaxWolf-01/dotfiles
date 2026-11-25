# sudo by a YubiKey touch, the server half: pam_rssh asks the ssh agent max
# forwards from the laptop (nix/home/sudo-touch.nix) to sign with one of the
# YubiKeys' ed25519-sk keys. `sufficient`, ahead of the password: no agent, no
# key in it, or no touch, and sudo asks for the password as before.
{ config, lib, ... }:
let
  # A key left untouched gives up after its own wait, which nothing here can
  # lengthen, so sudo asks this many times in a row: a missed touch is asked for
  # again, and the password comes only after the last ask. Every ask raises its
  # own notification on the laptop.
  asks = 5;
  rssh = config.security.pam.services.sudo.rules.auth.rssh;
in
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
  security.pam.services.sudo.rules.auth = lib.listToAttrs (map
    (i: lib.nameValuePair "rssh-again-${toString i}" {
      inherit (rssh) control modulePath settings;
      order = rssh.order + i;
    })
    (lib.range 1 (asks - 1)));
  programs.zsh.shellInit = builtins.readFile ./sudo-touch-login.zsh;

  environment.etc."ssh/sudo-touch/max".source = ../yubikey/sudo-sk-keys.pub;
}
