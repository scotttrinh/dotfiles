{
  flake,
  case,
}:
let
  invalidFile =
    if case == "unsafe" then
      {
        "../unsafe".text = "bad";
      }
    else if case == "reserved" then
      {
        "config.yml".text = "bad";
      }
    else if case == "conflicting" then
      {
        conflict = {
          text = "bad";
          source = ../modules/home/omp/default.nix;
        };
      }
    else
      throw "unknown invalid OMP file test case: ${case}";
in
flake.inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = flake.inputs.nixpkgs.legacyPackages.aarch64-darwin;
  modules = [
    flake.inputs.sops-nix.homeManagerModules.sops
    ../modules/home/omp/default.nix
    {
      home = {
        username = "omp-invalid-file-test";
        homeDirectory = "/Users/omp-invalid-file-test";
        stateVersion = "26.05";
      };
      omp = {
        enable = true;
        aiGateway.enable = false;
        agentFiles = invalidFile;
      };
    }
  ];
}
