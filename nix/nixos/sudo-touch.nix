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
      cue = true;
    };
  };
  security.pam.services.sudo.rssh = true;

  environment.etc."ssh/sudo-touch/max".source = ../yubikey/sudo-sk-keys.pub;
}
