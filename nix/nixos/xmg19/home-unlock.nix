# /home lives on its own LUKS volume (disk-config.nix) that no boot opens: the
# TPM unlocks the system disk for anyone holding the laptop, so the worktrees,
# Claude logins and dotdirs sit behind a key that only zephylux holds, in
# secrets/creds/raw/xmg19-home-luks. `host-unlock xmg19` (bin/) pipes it into
# host-unlock-receive below. Until then xmg19 runs without a /home: sshd,
# tailscale and the backups landing in /srv work, and a login lands in a home
# that is not there.
{ config, pkgs, lib, utils, ... }:

let
  homeUsers = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
  lingerUsers = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser && u.linger == true) config.users.users);
  # Home Manager's unit names, which escape the user name as systemd does a
  # path: agent-hl's is home-manager-agent\x2dhl.
  hmUnits = map (u: "home-manager-${utils.escapeSystemdPath u}")
    (lib.attrNames config.home-manager.users);

  # Each home and its TMPDIR (below). A TMPDIR that does not exist fails every
  # program that makes a temp file, nix and Home Manager's activation among
  # them, so both the unlock and every switch make sure of it.
  makeHomes = lib.concatMapStrings (user: ''
    home=$(${pkgs.getent}/bin/getent passwd ${user} | ${pkgs.coreutils}/bin/cut -d: -f6)
    group=$(${pkgs.coreutils}/bin/id -gn ${user})
    ${pkgs.coreutils}/bin/install -d -m 700 -o ${user} -g "$group" "$home" "$home/.tmp"
  '') homeUsers;

  receive = pkgs.writeShellApplication {
    name = "host-unlock-receive";
    runtimeInputs = with pkgs; [ cryptsetup coreutils getent systemd ];
    text = ''
      # Already unlocked this boot: the restarts below would end every user
      # manager, and with it every tmux pane and dispatch worker, which run as
      # its scopes. The mark is written last, so a run that failed after the
      # mount is finished by the next one.
      mark=/run/host-unlock-done
      if [ -e "$mark" ]; then
        cat > /dev/null
        ${makeHomes}
        echo "xmg19: /home was already unlocked"
        exit 0
      fi

      # The key arrives on stdin and goes straight to cryptsetup.
      if [ ! -e /dev/mapper/home ]; then
        cryptsetup open --key-file=- /dev/disk/by-partlabel/disk-home-luks home
      fi
      systemctl start home.mount

      hm_units=(${lib.escapeShellArgs hmUnits})
      linger_users=(${lib.escapeShellArgs lingerUsers})

      ${makeHomes}

      # What the boot skipped for want of /home (the conditions below).
      for unit in "''${hm_units[@]}"; do
        systemctl restart "$unit.service"
      done
      # A lingering user's manager started at boot without the units in its home.
      for user in "''${linger_users[@]}"; do
        systemctl restart "user@$(id -u "$user").service"
      done
      touch "$mark"
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

  # Without the condition Home Manager runs at boot against the empty mountpoint
  # and writes a user's files onto the system disk, under where /home mounts
  # later. Its own RequiresMountsFor would instead start home.mount at boot,
  # which waits 90 s for a device that is not there while logins wait on it.
  # The user managers are left to start: logins wait on them, and one that
  # skips itself costs every login a 25 s timeout.
  systemd.services = lib.genAttrs hmUnits (_: {
    unitConfig.ConditionPathIsMountPoint = "/home";
    unitConfig.RequiresMountsFor = lib.mkForce [ ];
  });

  # Temp files inside the encrypted volume, and kept across a power cut, where
  # /tmp is neither. pam_env sets it for logins, ssh commands and user services
  # alike; a program that hardcodes /tmp still writes there.
  environment.sessionVariables.TMPDIR = "$HOME/.tmp";
  # A switch with /home mounted can add a user the last unlock never saw.
  # Before the Home Manager units it starts; at boot /home is not mounted yet.
  system.activationScripts.home-tmp = {
    deps = [ "users" ];
    text = ''
      if ${pkgs.util-linux}/bin/mountpoint -q /home; then
        ${makeHomes}
      fi
    '';
  };
  systemd.tmpfiles.rules = [ "d /root/.tmp 0700 root root -" ];
}
