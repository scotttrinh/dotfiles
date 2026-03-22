{
  inputs = {
    # Principle inputs (updated by `nix run .#update`)
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-unified.url = "github:srid/nixos-unified";

    # Determinate Nix integration
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

    # Software inputs
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    eza.url = "https://flakehub.com/f/eza-community/eza/0.20.0";
    jj.url = "github:jj-vcs/jj/v0.39.0";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    llm-agents.url = "github:numtide/llm-agents.nix";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Local development inputs for OrbStack nooks VM
    nook.url = "github:scotttrinh/nook/15073811fbbf2155b4ad384768570656bfa810c1";
    nook.inputs.nixpkgs.follows = "nixpkgs";
    wigg.url = "github:scotttrinh/wigg";
    wigg.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ self, ... }:
    inputs.nixos-unified.lib.mkFlake {
      inherit inputs;
      root = ./.;
    };
}
