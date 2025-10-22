{ inputs, flake-parts-lib, ... }: {
  options.perSystem = flake-parts-lib.mkPerSystemOption ({ system, ... }: {
    imports = [
      "${inputs.nixpkgs}/nixos/modules/misc/nixpkgs.nix"
    ];

    nixpkgs = {
      hostPlatform = system;
      overlays = (import ../../overlays/default.nix { inherit inputs; });
      config.allowUnfree = true;
    };
  });
}