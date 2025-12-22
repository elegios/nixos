
{
  description = "NixOS config through a flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager = {
      # url = "github:elegios/home-manager/release-23.05";
      # url = "path:/home/vipa/Repositories/home-manager/";
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fish-gi = {
      url = "github:oh-my-fish/plugin-gi";
      flake = false;
    };
    miking-emacs = {
      url = "github:miking-lang/miking-emacs";
      flake = false;
    };
    typst-ts-mode = {
      url = "sourcehut:~meow_king/typst-ts-mode";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, home-manager, stylix, nixos-hardware, ... }@inputs:
    let hm = {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users.vipa = {
            imports = [ ./home.nix stylix.homeModules.stylix ];
          };

          home-manager.extraSpecialArgs = with inputs; { inherit fish-gi miking-emacs typst-ts-mode; };
        };
    in
      {
        nixosConfigurations = {
          "vipa-nixos" = nixpkgs.lib.nixosSystem rec {
            system = "x86_64-linux";
            modules = [
              ./modules/common-configuration.nix
              ./hosts/vipa-nixos/default.nix
              nixos-hardware.nixosModules.dell-xps-13-9380
              home-manager.nixosModules.home-manager
              hm
            ];
          };
          "viktpalm-linux" = nixpkgs.lib.nixosSystem rec {
            system = "x86_64-linux";
            modules = [
              nixos-hardware.nixosModules.common-cpu-intel
              nixos-hardware.nixosModules.common-pc-laptop
              nixos-hardware.nixosModules.common-pc-ssd
              {services = {fwupd.enable = nixpkgs.lib.mkDefault true; thermald.enable = nixpkgs.lib.mkDefault true;};}

              ./modules/common-configuration.nix
              ./modules/cachix.nix  # NOTE(vipa, 2025-11-08): Can be updated with cachix use <whatever> -m nixos -d ./modules
              ./hosts/viktpalm-linux/default.nix
              home-manager.nixosModules.home-manager
              hm
            ];
          };
          "vipa-homeserver" = nixpkgs.lib.nixosSystem rec {
            system = "x86_64-linux";
            modules = [
              ./modules/common-configuration.nix
              ./modules/cachix.nix
              ./hosts/vipa-homeserver/default.nix
              home-manager.nixosModules.home-manager
              hm
            ];
          };
        };
      };
}
