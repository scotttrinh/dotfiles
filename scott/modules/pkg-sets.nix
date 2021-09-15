{ config, pkgs, lib, ... }: {
  options = with lib; {
    pkgSets = mkOption {
      type = types.attrsOf (types.listOf types.package);
      default = { };
      description = "Package sets";
    };
  };

  config = {
    pkgSets = with pkgs; {
      system = [ nixFlakes direnv home-manager ];

      scott = [
        ripgrep
      ];
    };

    nixpkgs.overlays = [
      (new: old: {
        pkgShells =
          lib.mapAttrs (name: packages: old.mkShell { inherit name packages; })
          config.pkgSets;

        pkgSets =
          lib.mapAttrs (name: paths: old.buildEnv { inherit name paths; })
          config.pkgSets;
      })
    ];
  };
}
