{
  perSystem = { lib, system, inputs, self', ... }: {
    # Make our overlay available to the devShell
    # "Flake parts does not yet come with an endorsed module that initializes the pkgs argument.""
    # So we must do this manually; https://flake.parts/overlays#consuming-an-overlay
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = lib.attrValues self'.overlays;
      config.allowUnfree = true;
    };
  };
}