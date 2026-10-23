{
  description = "NixOS and Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rime = {
      url = "github:lukasl-dev/rime";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };
    # Only rime uses it. rime's own lock has not moved since 2026-01, and the
    # rust-overlay pinned there warns on every build (stdenv.isLinux is deprecated).
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin.url = "github:catppuccin/nix";
    greyline = {
      # Fork: upstream renders the lit hemisphere dark whenever the sun is south of
      # the equator (~23 Sep - 20 Mar), writes the PNG non-atomically onto the path
      # the desktop watches, and peaks at 577 MB for a 4K render. Reported upstream;
      # track it again once fixed there.
      url = "github:MaxWolf-01/greyline/review/all";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, rime, disko, catppuccin, greyline, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      mkHome = modules: home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit rime system; };
        modules = [ ./nix/home/common.nix ] ++ modules;
      };
    in {
      # NixOS systems
      nixosConfigurations."pc" = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit self rime system; };
        modules = [
          ./nix/nixos/pc/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit rime system; };
            home-manager.users.max = import ./nix/home/hosts/pc.nix;
            home-manager.users.agent = import ./nix/home/hosts/pc-agent.nix;
            home-manager.users.agent-hl = import ./nix/home/hosts/pc-agent-hl.nix;
          }
        ];
      };

      nixosConfigurations."xmg19" = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit self rime system; };
        modules = [
          disko.nixosModules.disko
          ./nix/nixos/xmg19/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit rime system; };
            home-manager.users.max = import ./nix/home/hosts/xmg19.nix;
            home-manager.users.agent = import ./nix/home/hosts/xmg19-agent.nix;
            home-manager.users.agent-hl = import ./nix/home/hosts/xmg19-agent-hl.nix;
            home-manager.backupFileExtension = "bak";
          }
        ];
      };

      # Installer ISO (SSH + keys baked in, for nixos-anywhere)
      nixosConfigurations."installer" = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          {
            users.users.root.openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPyy5xWC5my4ZPkc7mUEPKi/SfqdUEeq12pMKo5D/D4p"
            ];
            services.openssh = {
              enable = true;
              settings.PermitRootLogin = "yes";
            };
            networking.networkmanager.enable = true;
          }
        ];
      };

      # Home Manager standalone (non-NixOS machines)
      homeConfigurations."zephyrus" = mkHome [
        greyline.homeManagerModules.default
        ./nix/home/hosts/zephyrus.nix
      ];
      homeConfigurations."minimal" = mkHome [ ./nix/home/hosts/minimal.nix ];
      homeConfigurations."minimal-root" = mkHome [ ./nix/home/hosts/minimal-root.nix ];

      # What the test suites need beyond uv and a host's own tools: `nix develop -c make test`.
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ python3 fzf sops age ffmpeg restic dnsproxy openssl dig zbar notmuch strace ];
        # uv's Python finds no certificate store of its own on NixOS.
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        # The Chromium Playwright downloads is linked for a conventional Linux; on NixOS it
        # runs through nix-ld, which finds its libraries here. Elsewhere this is unread.
        shellHook = ''
          export NIX_LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath (with pkgs; [
            glib nspr nss at-spi2-core dbus expat libxkbcommon alsa-lib udev libgbm
            libX11 libXcomposite libXdamage libXext libXfixes libXrandr libxcb
          ])}''${NIX_LD_LIBRARY_PATH:+:$NIX_LD_LIBRARY_PATH}
        '';
      };
    };
}
