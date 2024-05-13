
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
    base16.url = "github:SenchoPens/base16.nix/b390e";
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
      inputs.base16.follows = "base16";
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
  outputs = { self, nixpkgs, home-manager, stylix, nixos-hardware, ... }@inputs: {
    nixosConfigurations = {
      "vipa-nixos" = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          stylix.nixosModules.stylix
          nixos-hardware.nixosModules.dell-xps-13-9380

          # make home-manager as a module of nixos
          # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
          home-manager.nixosModules.home-manager
          {
            stylix.homeManagerIntegration.followSystem = false;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.vipa = import ./home.nix;

            home-manager.extraSpecialArgs = with inputs; { inherit fish-gi miking-emacs typst-ts-mode; };
          }
        ];
      };
    };
  };
}
