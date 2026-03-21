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
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin.url = "github:catppuccin/nix";
  };

  outputs = { self, nixpkgs, home-manager, rime, disko, catppuccin, ... }@inputs:
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
          }
        ];
      };

      nixosConfigurations."xmg19" = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit self rime system; };
        modules = [
          disko.nixosModules.disko
          catppuccin.nixosModules.catppuccin
          ./nix/nixos/xmg19/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit rime system; };
            home-manager.users.max = {
              imports = [
                catppuccin.homeModules.catppuccin
                ./nix/home/hosts/xmg19.nix
              ];
            };
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
      homeConfigurations."zephyrus" = mkHome [ ./nix/home/hosts/zephyrus.nix ];
      homeConfigurations."minimal" = mkHome [ ./nix/home/hosts/minimal.nix ];
      homeConfigurations."minimal-root" = mkHome [ ./nix/home/hosts/minimal-root.nix ];
    };
}
