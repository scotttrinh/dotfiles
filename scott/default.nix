{ scott, flake-utils, mkDarwinSystem, nixpkgs, home-manager, nix-darwin, ... }@inputs:
let
  hostName = "cala-mbp-2021";
  systems = [ "aarch64-darwin" ];
in flake-utils.lib.eachSystem systems (system:
  mkDarwinSystem {
    inherit hostName system;

  nixosModules = [
    ({ config, pkgs, lib, ... }: {
      config._module.args = {
        inherit home-manager nixpkgs nix-darwin scott;
      };
    })
    (import ./modules)
  ];

  flakeOutputs = { pkgs, ... }@outputs:
    outputs // (with pkgs; {
      packages = pkgs;
      devShell = mkShell { pkgs = [ pkgSets.system pkgSets.scott ]; };
    });
})
