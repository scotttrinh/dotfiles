# Top-level flake glue to get our configuration working
{ inputs, self, ... }:

{
  imports = [
    inputs.nixos-unified.flakeModules.default
    inputs.nixos-unified.flakeModules.autoWire
  ];
  debug = true;
  perSystem = { self', lib, system, pkgs, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "fx" "devbox" ];
      overlays = [
        inputs.rust-overlay.overlays.default
      ];
    };

    # For 'nix fmt'
    formatter = pkgs.nixpkgs-fmt;

    # Enables 'nix run' to activate.
    packages.default = self'.packages.activate;

    packages.update = lib.mkForce (pkgs.writeShellApplication {
      name = "update-main-flake-inputs";
      runtimeInputs = [ pkgs.git pkgs.jq ];
      text = builtins.readFile ../../scripts/update-main-flake-inputs.sh;
    });

    packages.package-versions = pkgs.writeShellApplication {
      name = "package-versions";
      runtimeInputs = [ pkgs.git pkgs.jq ];
      text = builtins.readFile ../../scripts/refresh-package-versions.sh;
    };

    packages.update-llm-agents = pkgs.writeShellApplication {
      name = "update-llm-agents";
      runtimeInputs = [ pkgs.git pkgs.jq ];
      text = builtins.readFile ../../scripts/update-llm-agents.sh;
    };
  };
}
