{ flake }:
flake.inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = flake.inputs.nixpkgs.legacyPackages.aarch64-darwin;
  modules = [
    flake.inputs.sops-nix.homeManagerModules.sops
    ../modules/home/omp/default.nix
    {
      home = {
        username = "omp-invalid-provider-test";
        homeDirectory = "/Users/omp-invalid-provider-test";
        stateVersion = "26.05";
      };
      omp = {
        enable = true;
        aiGateway.enable = false;
        modelProviders.invalid = {
          baseUrl = "https://example.invalid";
          apiKey = "secret";
          api = "invalid-api";
          models = [{ id = "invalid"; }];
        };
      };
    }
  ];
}
