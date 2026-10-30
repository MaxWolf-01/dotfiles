# sudo by a YubiKey touch, the laptop's half; docs/sudo-touch.md registers the
# keys and says how to back out.
#
# Here sudo asks pam_u2f, which `./setup ubuntu` puts in /etc/pam.d/sudo, and
# pam_u2f reads which keys count from ~/.config/Yubico/u2f_keys, linked below.
#
# pc and xmg19 ask the ssh agent forwarded from here instead (pam_rssh,
# nix/nixos/sudo-touch.nix). That agent is a second one, holding only the
# YubiKeys' ed25519-sk keys, and only those two hosts get it: the everyday agent,
# with id_ed25519 in it, is forwarded nowhere. Every signature it makes waits for
# a touch, so a host it is forwarded to can ask for one but never take one
# silently, and while it waits a prompt-waits file names the host that asked
# (ssh-sk-askpass.sh).
{ config, pkgs, lib, ... }:
let
  keys = ../yubikey;
  # The machines whose sudo takes a touch, by the ssh block that reaches each:
  # the hosts whose configuration.nix imports nix/nixos/sudo-touch.nix.
  forwarded = {
    pc = "pc";
    xmg19 = "xmg xmg19";
  };
  # Made by `ssh-keygen -t ed25519-sk`, one per YubiKey; a handle is useless
  # without the key it was made on.
  handles = map (key: "${config.home.homeDirectory}/.ssh/id_ed25519_sk_${key}") [ "keychain" "backup" ];

  askpass = pkgs.writeShellApplication {
    name = "ssh-sk-askpass";
    runtimeInputs = with pkgs; [ coreutils gawk gnused iproute2 jq ];
    # No errexit: a host it fails to place is still a prompt to show.
    bashOptions = [ "nounset" "pipefail" ];
    text = builtins.readFile ./ssh-sk-askpass.sh;
  };
  hosts = pkgs.writeText "ssh-sk-hosts" (lib.concatLines (lib.mapAttrsToList
    (name: block: "${config.programs.ssh.settings.${block}.data.HostName} ${name}")
    forwarded));

  # Loads the handles there are, then checks that the agent holds sk keys and
  # nothing else, emptying it if not: what it holds is what pc and xmg19 see.
  load = pkgs.writeShellScript "ssh-sk-agent-load" ''
    PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.gnugrep pkgs.openssh ]}
    # ssh-agent -D says nothing when its socket is ready; it takes milliseconds.
    for _ in $(seq 50); do [ -S "$SSH_AUTH_SOCK" ] && break; sleep 0.1; done
    for handle in ${lib.escapeShellArgs handles}; do
      if [ -f "$handle" ]; then
        ssh-add "$handle"
      else
        echo "no key handle at $handle yet; docs/sudo-touch.md makes it"
      fi
    done
    # ssh-add -L exits 1, saying so on stdout, when the agent holds nothing.
    if held=$(ssh-add -L) && grep -v '^sk-ssh-ed25519@openssh.com ' <<<"$held" | grep -q .; then
      ssh-add -D
      echo "the YubiKey agent held a key that is not an ed25519-sk key; emptied it" >&2
      exit 1
    fi
  '';
in
{
  xdg.configFile."Yubico/u2f_keys" = lib.mkIf (builtins.pathExists (keys + "/u2f_keys")) {
    source = keys + "/u2f_keys";
  };

  systemd.user.services.ssh-sk-agent = {
    Unit.Description = "SSH agent holding only the YubiKeys' sk keys, forwarded to ${lib.concatStringsSep " and " (lib.attrNames forwarded)}";
    Service = {
      ExecStartPre = "${pkgs.coreutils}/bin/rm -f %t/ssh-sk-agent";
      ExecStart = "${pkgs.openssh}/bin/ssh-agent -D -a %t/ssh-sk-agent";
      ExecStartPost = "${load}";
      Environment = [
        "SSH_AUTH_SOCK=%t/ssh-sk-agent"
        "SSH_SK_AGENT_SOCK=%t/ssh-sk-agent"
        "SSH_SK_HOSTS=${hosts}"
        "SSH_ASKPASS=${askpass}/bin/ssh-sk-askpass"
        # ssh-agent shows a touch request only with a display, which a user
        # unit does not have; this makes it run the askpass regardless.
        "SSH_ASKPASS_REQUIRE=force"
      ];
    };
    Install.WantedBy = [ "default.target" ];
  };

  # %i is the uid, so the path is the unit's %t/ssh-sk-agent in any process,
  # including one without XDG_RUNTIME_DIR.
  programs.ssh.settings = lib.mapAttrs' (_: block: lib.nameValuePair block {
    ForwardAgent = "/run/user/%i/ssh-sk-agent";
  }) forwarded;
}
