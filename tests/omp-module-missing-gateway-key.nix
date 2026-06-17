{ flake }:
flake.inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = flake.inputs.nixpkgs.legacyPackages.aarch64-darwin;
  modules = [
    flake.inputs.sops-nix.homeManagerModules.sops
    ../modules/home/omp/default.nix
    {
      home = {
        username = "omp-missing-gateway-key-test";
        homeDirectory = "/Users/omp-missing-gateway-key-test";
        stateVersion = "26.05";
      };
      omp.enable = true;
    }
  ];
}
