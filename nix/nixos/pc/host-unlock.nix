# What pc keeps locked after a boot, and the command that unlocks it with the
# secrets `host-unlock pc` (bin/) sends from zephylux, one per ssh call, on
# stdin: the age key (decrypted to tmpfs), the SSH key's passphrase (the key
# goes into the agent), and the passphrases of the encrypted ZFS datasets.
# Without it they wait for max's first login (secrets/zshrc) and `zfs-unlock`,
# and the backups that need them skip until then.
{ config, pkgs, lib, ... }:

let
  zfs = config.boot.zfs.package;

  # Root's half: the dataset name is checked against the three encrypted ones,
  # since any process of max's may call it without a password.
  zfsUnlock = pkgs.writeShellApplication {
    name = "host-unlock-zfs";
    runtimeInputs = [ zfs pkgs.systemd ];
    text = ''
      case ''${1:-} in
        phone|general|encrypted) dataset="tank/max/$1" ;;
        *) echo "host-unlock-zfs: not an encrypted dataset: ''${1:-}" >&2; exit 2 ;;
      esac
      if [ "$(zfs get -H -o value keystatus "$dataset")" = available ]; then
        cat > /dev/null
      else
        zfs load-key "$dataset"
      fi
      zfs mount "$dataset" 2>/dev/null || [ "$(zfs get -H -o value mounted "$dataset")" = yes ]
      if [ "$1" = encrypted ]; then
        systemctl start copyparty.service
      fi
    '';
  };

  receive = pkgs.writeShellApplication {
    name = "host-unlock-receive";
    runtimeInputs = with pkgs; [ coreutils openssh systemd ];
    text = ''
      runtime="/run/user/$(id -u)"
      case ''${1:-} in
        age-key)
          if [ -s "$runtime/age-key.txt" ]; then cat > /dev/null; exit 0; fi
          (umask 077; cat > "$runtime/age-key.txt")
          ;;
        ssh-key)
          export SSH_AUTH_SOCK="$runtime/ssh-agent"
          if ssh-add -l > /dev/null 2>&1; then cat > /dev/null; exit 0; fi
          dir=$(mktemp -d -p "$runtime")
          trap 'rm -rf "$dir"' EXIT
          (umask 077; cat > "$dir/passphrase")
          printf '#!/bin/sh\ncat %q\n' "$dir/passphrase" > "$dir/askpass"
          chmod 700 "$dir/askpass"
          SSH_ASKPASS="$dir/askpass" SSH_ASKPASS_REQUIRE=force ssh-add "$HOME/.ssh/id_ed25519" < /dev/null
          ;;
        zfs)
          sudo /run/current-system/sw/bin/host-unlock-zfs "''${2:-}"
          ;;
        finish)
          systemctl --user start --no-block tmux-resume-restored.service backup-catchup.target
          echo "pc: unlocked, sessions resuming, backups catching up"
          ;;
        *)
          echo "usage: host-unlock-receive age-key|ssh-key|zfs <dataset>|finish, the secret on stdin" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  environment.systemPackages = [ receive zfsUnlock ];

  security.sudo.extraRules = [{
    users = [ "max" ];
    commands = [{
      command = "/run/current-system/sw/bin/host-unlock-zfs";
      options = [ "NOPASSWD" ];
    }];
  }];
}
