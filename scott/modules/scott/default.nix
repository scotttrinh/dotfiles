{ config, pkgs, lib, scott, home-manager, nix-darwin, nixpkgs, ... }@args:
{
  home-manager.users.scotttrinh = {
    home.packages = config.pkgSets.scott;
  };
}
