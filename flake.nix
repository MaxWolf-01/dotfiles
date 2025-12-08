{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      mkHome = modules: home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        inherit modules;
      };
    in {
      homeConfigurations."zephyrus" = mkHome [
        ./nix/home/common.nix
        ./nix/home/hosts/zephyrus.nix
      ];
      homeConfigurations."minimal" = mkHome [
        ./nix/home/common.nix
        ./nix/home/hosts/minimal.nix
      ];
      homeConfigurations."xmg19" = mkHome [
        ./nix/home/common.nix
        ./nix/home/hosts/xmg19.nix
      ];
    };
}
