{ config, pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs = {
    forceImportRoot = false;
    extraPools = [ "tank" ];
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
  };

  # NVIDIA MPS — concurrent GPU sharing across containers
  systemd.services.nvidia-mps = {
    description = "NVIDIA CUDA Multi-Process Service";
    after = [ "nvidia-persistenced.service" ];
    requires = [ "nvidia-persistenced.service" ];
    wantedBy = [ "multi-user.target" ];
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

  system.stateVersion = "26.05";
}
