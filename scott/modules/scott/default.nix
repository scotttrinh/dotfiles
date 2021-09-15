{ config, pkgs, lib, scott, home-manager, nix-darwin, nixpkgs, ... }@args:
{
  home-manager.users.${USER} = {
    home.packages = config.pkgSets.scott;
  };
}
