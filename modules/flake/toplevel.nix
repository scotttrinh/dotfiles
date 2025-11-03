# Top-level flake glue to get our configuration working
{ inputs, self, ... }:

{
  imports = [
    inputs.nixos-unified.flakeModules.default
    inputs.nixos-unified.flakeModules.autoWire
  ];
  debug = true;
  perSystem = { self', lib, system, pkgs, ... }: {

    # For 'nix fmt'
    formatter = pkgs.nixpkgs-fmt;

    # Enables 'nix run' to activate.
    packages.default = self'.packages.activate;
  };
}