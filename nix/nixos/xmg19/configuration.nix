{ config, pkgs, lib, self, ... }:

{
  imports = [
    ./disk-config.nix
    ./home-unlock.nix
    # About three quarters of the 31G, leaving max's sessions and the GPU
    # driver room.
    (import ../agent-user.nix {
      memoryMax = "24G";
      dispatcherKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPyy5xWC5my4ZPkc7mUEPKi/SfqdUEeq12pMKo5D/D4p" # zephyrus
      ];
    })
    ./gpu-queue.nix
    ./backup-target.nix
    ../host-recorder.nix
    ../journald.nix
    ../uv-python.nix
  ];

  hardware.facter.reportPath = ./facter.json;

  # Boot
  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.memtest86.enable = true;
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

  # NVIDIA (GTX 1660 Ti = Turing). videoDrivers is how NixOS picks the driver;
  # no X server runs here.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;

  # XMG uses Clevo/Tongfang chassis (uniwill_wmi).
  hardware.tuxedo-drivers.enable = true;

  boot = {
    # systemd in stage 1 is what reads the TPM: cryptroot unlocks unattended
    # (disk-config.nix), so a reboot or an rtcwake wake-up comes all the way up.
    initrd.systemd.enable = true;
    initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
    kernelParams = [
      "nvidia_drm.fbdev=1"
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
      "nvidia.NVreg_TemporaryFilePath=/var/tmp"
      # GSP firmware off, which runtime D3 needs (hardware.nvidia below)
      "nvidia.NVreg_EnableGpuFirmware=0"
      # One of the two Corsair CM4X16GE2666C18S2 sticks flips bits at physical
      # 0x2610b84d5-0x2610bff1d (stressapptest, 2026-10-17). This keeps Linux off
      # the 16M around it. The address holds only for this pair of sticks in these
      # slots: drop the line when the RAM changes.
      "memmap=16M$0x260800000"
    ];
    blacklistedKernelModules = [ "nouveau" ];
  };

  # The dGPU powers itself off when idle (runtime D3, D3cold) and back on when
  # a program opens it, CUDA included. On Turing only the proprietary module
  # with GSP firmware off does that; the open one reports "Runtime D3 status:
  # Not supported" (NVIDIA README, "Open Linux Kernel Modules", Known Issues).
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    gsp.enable = false;
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

  # finegrained hands the dGPU to runtime PM with a udev rule on the driver's
  # bind, but the driver binds in the initrd, before that rule exists, and the
  # coldplug that replays events afterwards sends add, not bind. Without this
  # rule power/control stays "on" and the card never powers down.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
  '';

  # The recorder's xmg19 sensor set reads the dGPU through nvidia-smi.
  systemd.services.host-recorder.path = [ config.hardware.nvidia.package.bin ];

  environment.systemPackages = with pkgs; [
    git
    nvtopPackages.nvidia
  ];

  # facter turns Bluetooth on wherever it finds the radio; nothing here uses it.
  hardware.bluetooth.enable = false;

  # Power management (laptop)
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;
  services.upower.enable = true;

  # A worker host never sleeps: the lid and logind's idle action leave it
  # running, and systemd refuses every sleep state besides.
  # sleepfor's (zsh/functions) `rtcwake -m off` is a poweroff, not a sleep, and still works.
  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
    IdleAction = "ignore";
  };

  # Keep wifi alive during idle
  networking.networkmanager.wifi.powersave = false;

  # Per-network stable random MAC (privacy on public wifi)
  networking.networkmanager.wifi.macAddress = "stable";

  # Encrypted DNS to Quad9 (mirrors `setup net_harden` on non-NixOS hosts);
  # opportunistic so captive portals still work pre-auth. tailscaled stays out
  # of DNS here (--accept-dns=false below), so this and the LAN router answer
  # everything. Should tailscaled ever own DNS again, no domains = [ "~." ]: it
  # would tie with tailscaled's ~. and let Quad9 answer blocked domains
  # (docs/dns.md).
  services.resolved = {
    enable = true;
    settings.Resolve.DNSOverTLS = "opportunistic";
  };
  networking.nameservers = [ "9.9.9.9#dns.quad9.net" "149.112.112.112#dns.quad9.net" ];

  # Docker + GPU passthrough
  virtualisation.docker = {
    enable = true;
    daemon.settings.features.cdi = true;
    autoPrune.enable = true;
  };
  hardware.nvidia-container-toolkit.enable = true;

  # Tailscale. --accept-dns=false keeps xmg19 off the tailnet's ad-blocking
  # resolver, as pc: a blocked domain is a silent NXDOMAIN to a worker or a job
  # (docs/dns.md). Tagged tag:server in secrets/tailscale/policy.hujson, so it
  # opens no connection into the tailnet.
  services.tailscale.enable = true;
  services.tailscale.extraSetFlags = [ "--accept-dns=false" ];

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # User
  users.users.max = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "networkmanager" ];
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

  system.configurationRevision = self.rev or self.dirtyRev or "unknown";

  system.stateVersion = "26.05";
}
