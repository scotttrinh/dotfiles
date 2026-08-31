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
    omp = llm-agents.omp;
    superpowers = self.packages.${system}.superpowers;
  };

  codex = {
    enable = true;
    package = config.selectedPackages.codex;
  };

  omp = {
    enable = true;
    package = config.selectedPackages.omp;
    setupVersion = 1;
    appearance = {
      themeDark = "titanium";
      themeLight = "light";
      symbolPreset = "nerd";
    };
    interaction.setupWizard = false;
    providers.webSearch = "auto";
    plugins.superpowers.package = config.selectedPackages.superpowers;
  };

  home.stateVersion = "24.11";
}
