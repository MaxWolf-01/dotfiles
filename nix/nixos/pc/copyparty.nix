{ pkgs, ... }:

let
  secrets = "/home/max/.dotfiles/secrets";
in
{
  systemd.services.copyparty = {
    description = "copyparty file server (tailnet-only)";
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.copyparty pkgs.bash pkgs.util-linux ];
    serviceConfig = {
      User = "max";
      Group = "users";
      ExecStart = "${secrets}/copyparty-run";
      Restart = "on-failure";
      RestartSec = 10;

      # Sandboxing: ffmpeg parses media, isolate the service from key material
      NoNewPrivileges = true;
      ProtectSystem = "full";
      InaccessiblePaths = [
        "-/home/max/.ssh"
        "-/home/max/.local/secrets"
        "-/run/user"
        "-${secrets}/api_keys"
        "-${secrets}/passwords"
        "-${secrets}/ssh"
        "-${secrets}/env"
      ];
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
    };
  };

  # Allow max to manage this service without password
  security.sudo.extraRules = [{
    users = [ "max" ];
    commands = [
      { command = "/run/current-system/sw/bin/systemctl start copyparty.service"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/systemctl stop copyparty.service"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/systemctl restart copyparty.service"; options = [ "NOPASSWD" ]; }
    ];
  }];
}
