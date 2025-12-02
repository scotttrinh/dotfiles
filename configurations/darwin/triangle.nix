# See /modules/darwin/* for actual settings
# This file is just *top-level* configuration.
{ flake, lib, pkgs, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    self.darwinModules.default
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  networking.hostName = "triangle";

  system.primaryUser = "scotttrinh";

  # Automatically move old dotfiles out of the way
  #
  # Note that home-manager is not very smart, if this backup file already exists it
  # will complain "Existing file .. would be clobbered by backing up". To mitigate this,
  # we try to use as unique a backup file extension as possible.
  home-manager.backupFileExtension = "nixos-unified-template-backup";

  # Work-specific home-manager configuration
  # This merges with configurations/home/scotttrinh.nix
  home-manager.users.scotttrinh = {
    home.packages = with pkgs; [
      git-lfs
      fnm
      nodePackages.vercel
    ];
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  homebrew = {
    casks = [
      "1password"
      "slack"
      "cursor"
    ];
  };
}
