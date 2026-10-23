{ config
, flake
, pkgs
, ...
}:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  system = pkgs.stdenv.hostPlatform.system;
  llm-agents = inputs.llm-agents.packages.${system};
in
{
  imports = [
    self.homeModules.default
  ];

  # Defined by /modules/home/me.nix
  # And used all around in /modules/home/*
  me = {
    username = "scotttrinh";
    fullname = "Scott Trinh";
    email = "scott@scotttrinh.com";
    gitSigning.enable = true;
  };

  selectedPackages = {
    codex = llm-agents.codex;
  };

  codex = {
    enable = true;
    package = config.selectedPackages.codex;
  };

  home.stateVersion = "24.11";
}
