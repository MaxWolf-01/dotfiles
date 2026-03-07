{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./youtube-download.nix
  ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "nomodeset" ];

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs = {
    forceImportRoot = false;
    extraPools = [ "tank" ];
    requestEncryptionCredentials = false;
  };

  # Network
  networking.hostName = "pc";
  networking.hostId = "92d38672"; # required for ZFS — from /etc/machine-id

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    trustedInterfaces = [ "tailscale0" ];
  };

  # NVIDIA (GTX 1650 = Turing)
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;

  hardware.nvidia = {
    open = true;
    nvidiaSettings = false;
    nvidiaPersistenced = true;
    modesetting.enable = false;
  };

  # NVIDIA MPS — concurrent GPU sharing across containers
  systemd.services.nvidia-mps = {
    description = "NVIDIA CUDA Multi-Process Service";
    after = [ "nvidia-persistenced.service" ];
    requires = [ "nvidia-persistenced.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ config.hardware.nvidia.package.bin ];
    serviceConfig = {
      Type = "forking";
      ExecStart = "${config.hardware.nvidia.package.bin}/bin/nvidia-cuda-mps-control -d";
      ExecStop = "${pkgs.writeShellScript "nvidia-mps-stop" ''
        echo quit | ${config.hardware.nvidia.package.bin}/bin/nvidia-cuda-mps-control
      ''}";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Docker + GPU passthrough (CDI)
  virtualisation.docker = {
    enable = true;
    daemon.settings.features.cdi = true;
    autoPrune.enable = true;
  };

  hardware.nvidia-container-toolkit.enable = true;

  # PO token server for yt-dlp (anti-bot verification for YouTube)
  virtualisation.oci-containers.containers.bgutil-pot = {
    image = "brainicism/bgutil-ytdlp-pot-provider:latest";
    ports = [ "127.0.0.1:4416:4416" ];
    autoStart = true;
  };

  # ZFS maintenance (pool on HDDs, auto-imported)
  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
  };

  # Tailscale
  services.tailscale.enable = true;

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
    extraConfig = ''
      Match Address 100.64.0.0/10
        PasswordAuthentication yes
    '';
  };

  # User
  users.users.max = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.zsh;
    linger = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAjII9WXpRDSR9Ac8M2ajf/DsQbBReeI3q7V9FSsXIlO"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPyy5xWC5my4ZPkc7mUEPKi/SfqdUEeq12pMKo5D/D4p"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE9y4XD7AHJ9PbUTMtUhS3VzTewwbE/zNZkrlywwrdnL max@zephylux"
    ];
  };
  programs.zsh.enable = true;

  # Nix
  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "max" ];
  };

  # Disable deprecated udev-settle (times out waiting for NVIDIA/ZFS events, nothing needs it)
  systemd.services.systemd-udev-settle.serviceConfig.ExecStart = [ "" "${pkgs.coreutils}/bin/true" ];

  # Temporary boot diagnostics — remove after debugging headless boot hang
  boot.initrd.postMountCommands = ''
    echo "INITRD-ROOT-MOUNTED $(date -Iseconds 2>/dev/null || date)" >> /mnt-root/var/log/boot-diag.log
  '';
  boot.postBootCommands = ''
    echo "STAGE2-PRE-SYSTEMD $(date -Iseconds)" >> /var/log/boot-diag.log
  '';
  systemd.services.boot-diag-pre = {
    description = "Boot diag: before module loading";
    unitConfig.DefaultDependencies = false;
    after = [ "local-fs.target" ];
    before = [ "systemd-modules-load.service" ];
    wantedBy = [ "sysinit.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "boot-diag-pre" ''
        echo "PRE-MODULES $(date -Iseconds)" >> /var/log/boot-diag.log
      '';
    };
  };
  systemd.services.boot-diag-post = {
    description = "Boot diag: after module loading";
    unitConfig.DefaultDependencies = false;
    after = [ "systemd-modules-load.service" "local-fs.target" ];
    wantedBy = [ "sysinit.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "boot-diag-post" ''
        echo "POST-MODULES $(date -Iseconds)" >> /var/log/boot-diag.log
      '';
    };
  };
  systemd.services.boot-diag-net = {
    description = "Boot diag: network up";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "boot-diag-net" ''
        echo "NETWORK-UP $(date -Iseconds)" >> /var/log/boot-diag.log
      '';
    };
  };

  system.stateVersion = "26.05";
}
