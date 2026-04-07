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

  # XMG uses Clevo/Tongfang chassis (uniwill_wmi). tuxedo-drivers loads but
  # Fn+F-key media combos send unmapped scancodes (0xf8 etc.) — no volume/brightness.
  # Needs udev hwdb rules to map scancodes to keycodes. Ubuntu ships these; NixOS doesn't.
  # TODO: add hwdb rules or find the right scancode→keycode mappings for this model.
  hardware.tuxedo-drivers.enable = true;

  boot = {
    initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
    kernelParams = [
      "nvidia_drm.fbdev=1"
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
      "nvidia.NVreg_TemporaryFilePath=/var/tmp"
    ];
    blacklistedKernelModules = [ "nouveau" ];
    resumeDevice = "/dev/vg-xmg19/swap";
  };

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

  environment.systemPackages = with pkgs; [
    git firefox
    nvidia-vaapi-driver
    nvtopPackages.nvidia
  ];

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

  # PAM (needed for hyprlock)
  security.pam.services.hyprlock = {};

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
  services.blueman.enable = true;

  # Power management (laptop)
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;
  services.upower.enable = true;
  services.udisks2.enable = true;

  # Lid/idle: hypridle controls screen/lock/suspend, not logind
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
    IdleAction = "ignore";
  };

  # Keep wifi alive during idle
  networking.networkmanager.wifi.powersave = false;

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
    initialPassword = "max"; # change with passwd after first login
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPyy5xWC5my4ZPkc7mUEPKi/SfqdUEeq12pMKo5D/D4p"
    ];
  };
  programs.zsh.enable = true;
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = [ config.hardware.nvidia.package ];

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
