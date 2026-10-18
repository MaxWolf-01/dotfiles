# /home lives on its own LUKS volume (disk-config.nix) that no boot opens: the
# TPM unlocks the system disk for anyone holding the laptop, so the worktrees,
# Claude logins and dotdirs sit behind a key that only zephylux holds, in
# secrets/creds/raw/xmg19-home-luks. `host-unlock xmg19` (bin/) pipes it into
# host-unlock-receive below. Until then xmg19 runs without a /home: sshd,
# tailscale and the backups landing in /srv work, and a login lands in a home
# that is not there.
{ config, pkgs, lib, ... }:

let
  homeUsers = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
  lingerUsers = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser && u.linger == true) config.users.users);
  hmUsers = lib.attrNames config.home-manager.users;

  receive = pkgs.writeShellApplication {
    name = "host-unlock-receive";
    runtimeInputs = with pkgs; [ cryptsetup coreutils getent systemd ];
    text = ''
      # The key arrives on stdin and goes straight to cryptsetup.
      if [ ! -e /dev/mapper/home ]; then
        cryptsetup open --key-file=- /dev/disk/by-partlabel/disk-home-luks home
      fi
      systemctl start home.mount

      home_users=(${lib.escapeShellArgs homeUsers})
      hm_users=(${lib.escapeShellArgs hmUsers})
      linger_users=(${lib.escapeShellArgs lingerUsers})

      for user in "''${home_users[@]}"; do
        home=$(getent passwd "$user" | cut -d: -f6)
        group=$(id -gn "$user")
        install -d -m 700 -o "$user" -g "$group" "$home"
        install -d -m 700 -o "$user" -g "$group" "$home/.tmp"
      done

      # What the boot skipped for want of /home (the conditions below).
      for user in "''${hm_users[@]}"; do
        systemctl restart "home-manager-$user.service"
      done
      for user in "''${linger_users[@]}"; do
        systemctl start "user@$(id -u "$user").service"
      done
      echo "xmg19: /home unlocked"
    '';
  };
in
{
  environment.systemPackages = [ receive ];

  # max runs it over ssh from zephylux with the key on stdin, so no password
  # prompt may stand in the way. It opens nothing without the right key.
  security.sudo.extraRules = [{
    users = [ "max" ];
    commands = [{
      command = "/run/current-system/sw/bin/host-unlock-receive";
      options = [ "NOPASSWD" ];
    }];
  }];

  # Without the condition these run at boot against the empty mountpoint and
  # write a user's files onto the system disk, under where /home mounts later.
  # Home Manager's own RequiresMountsFor would instead start home.mount at boot,
  # which waits 90 s for a device that is not there while logins wait on it.
  systemd.services = {
    "user@".unitConfig.ConditionPathIsMountPoint = "/home";
  } // lib.genAttrs (map (u: "home-manager-${u}") hmUsers) (_: {
    unitConfig.ConditionPathIsMountPoint = "/home";
    unitConfig.RequiresMountsFor = lib.mkForce [ ];
  });

  # Temp files inside the encrypted volume, and kept across a power cut, where
  # /tmp is neither. pam_env sets it for logins, ssh commands and user services
  # alike; a program that hardcodes /tmp still writes there.
  environment.sessionVariables.TMPDIR = "$HOME/.tmp";
  systemd.tmpfiles.rules = [ "d /root/.tmp 0700 root root -" ];
}
