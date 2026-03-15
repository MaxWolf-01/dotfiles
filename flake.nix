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
  };

  outputs = { self, nixpkgs, home-manager, rime, disko, ... }:
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
          ./nix/nixos/xmg19/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit rime system; };
            home-manager.users.max = import ./nix/home/hosts/xmg19.nix;
            home-manager.backupFileExtension = "bak";
          }
        ];
      };

      # Home Manager standalone (non-NixOS machines)
      homeConfigurations."zephyrus" = mkHome [ ./nix/home/hosts/zephyrus.nix ];
      homeConfigurations."minimal" = mkHome [ ./nix/home/hosts/minimal.nix ];
      homeConfigurations."minimal-root" = mkHome [ ./nix/home/hosts/minimal-root.nix ];
      homeConfigurations."xmg19" = mkHome [ ./nix/home/hosts/xmg19.nix ];
    };
}
