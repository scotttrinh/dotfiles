{ config, pkgs, lib, scott, ... }: {
  system.stateVersion = 4;

  nix.package = pkgs.nixUnstable;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  environment.systemPackages = config.pkgSets.system;
}
