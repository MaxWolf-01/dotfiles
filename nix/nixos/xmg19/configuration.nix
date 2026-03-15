{ config, pkgs, lib, self, ... }:

{
  imports = [
    ./disk-config.nix
  ];

  hardware.facter.reportPath = ./facter.json;

  # Boot
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    efi.efiSysMountPoint = "/boot/efi";
  };

  # Network
  networking.hostName = "xmg19";
  networking.networkmanager.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    trustedInterfaces = [ "tailscale0" ];
  };

  # Locale
  time.timeZone = "Europe/Vienna";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "de-latin1-nodeadkeys";

  # NVIDIA (GTX 1660 Ti = Turing)
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = false;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
    powerManagement.enable = true;
    powerManagement.finegrained = true;
  };

  # Hyprland
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # Display manager (SDDM, Wayland-native)
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  # Bluetooth
  hardware.bluetooth.enable = true;

  # Power management (laptop)
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;

  # Docker + GPU passthrough
  virtualisation.docker = {
    enable = true;
    daemon.settings.features.cdi = true;
    autoPrune.enable = true;
  };
  hardware.nvidia-container-toolkit.enable = true;

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
    extraGroups = [ "wheel" "docker" "networkmanager" "input" ];
    shell = pkgs.zsh;
    linger = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE9y4XD7AHJ9PbUTMtUhS3VzTewwbE/zNZkrlywwrdnL max@zephylux"
    ];
  };
  programs.zsh.enable = true;

  # Nix
  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "max" ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Portal config for Hyprland (file picker, screen sharing)
  xdg.portal = {
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "hyprland" "gtk" ];
  };

  system.configurationRevision = self.rev or self.dirtyRev or "unknown";

  system.stateVersion = "26.05";
}
