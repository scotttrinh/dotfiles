# Bootstrap File Templates

These are the starting-point templates for Phase 3. Replace `<PLACEHOLDERS>` with values from discovery and identity setup.

## flake.nix

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-unified.url = "github:srid/nixos-unified";
  };

  outputs = inputs@{ self, ... }:
    inputs.nixos-unified.lib.mkFlake {
      inherit inputs;
      root = ./.;
    };
}
```

> For Linux-only setups, change the nixpkgs URL to `github:nixos/nixpkgs/nixos-25.11`.

## modules/home/default.nix — Auto-Import

```nix
# Automatically imports every .nix file in this directory.
{
  imports =
    with builtins;
    map
      (fn: ./${fn})
      (filter (fn: fn != "default.nix") (attrNames (readDir ./.)));
}
```

This pattern means adding a new module is just creating a file — no import wiring needed.

## modules/home/me.nix — Identity Options

```nix
{ config, lib, ... }:
{
  options.me = {
    username = lib.mkOption {
      type = lib.types.str;
      description = "Your username as shown by `id -un`";
    };
    fullname = lib.mkOption {
      type = lib.types.str;
      description = "Your full name for use in Git config";
    };
    email = lib.mkOption {
      type = lib.types.str;
      description = "Your email for use in Git config";
    };
  };
  config = {
    home.username = config.me.username;
  };
}
```

## modules/home/git.nix — Git Config

```nix
{ config, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = config.me.fullname;
        email = config.me.email;
      };
      init.defaultBranch = "main";
    };
    ignores = [
      ".DS_Store"
      ".direnv"
      ".envrc"
      "*~"
      "*.swp"
    ];
  };
}
```

## modules/home/shell.nix — Zsh + Starship

```nix
{ ... }:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
  };

  programs.zoxide.enable = true;

  programs.starship = {
    enable = true;
    settings = {
      username = {
        disabled = false;
        show_always = true;
      };
      hostname = {
        ssh_only = false;
        disabled = false;
      };
    };
  };
}
```

## configurations/home/\<username\>.nix — User Config

```nix
{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [ self.homeModules.default ];

  me = {
    username = "<USERNAME>";
    fullname = "<FULLNAME>";
    email = "<EMAIL>";
  };

  home.stateVersion = "24.11";
}
```

## configurations/darwin/\<hostname\>.nix — macOS Host

Only needed for macOS.

```nix
{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [ self.darwinModules.default ];

  nixpkgs.hostPlatform = "<ARCH>-darwin";  # aarch64-darwin or x86_64-darwin
  nixpkgs.config.allowUnfree = true;

  networking.hostName = "<HOSTNAME>";
  system.primaryUser = "<USERNAME>";

  home-manager.backupFileExtension = "nix-backup";

  system.stateVersion = 4;
}
```

## modules/darwin/default.nix — macOS System Defaults

```nix
{ ... }:
{
  security.pam.services.sudo_local.touchIdAuth = true;

  system = {
    defaults = {
      dock = {
        autohide = true;
        orientation = "left";
        tilesize = 32;
      };
      finder = {
        AppleShowAllExtensions = true;
        ShowPathbar = true;
        ShowStatusBar = true;
      };
    };
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };
  };
}
```

## modules/flake/toplevel.nix — Flake Infrastructure

```nix
{ inputs, ... }:
{
  imports = [
    inputs.nixos-unified.flakeModules.default
    inputs.nixos-unified.flakeModules.autoWire
  ];

  perSystem = { pkgs, ... }: {
    formatter = pkgs.nixpkgs-fmt;
  };
}
```
