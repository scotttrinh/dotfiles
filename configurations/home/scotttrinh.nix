{
  config,
  flake,
  pkgs,
  ...
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

  codex = {
    enable = true;
    package = llm-agents.codex;
  };

  sops.secrets.omp_ai_gateway_api_key = {
    key = "OMP_AI_GATEWAY_API_KEY";
    mode = "0400";
  };

  omp = {
    enable = true;
    package = llm-agents.omp;
    setupVersion = 1;
    appearance = {
      themeDark = "titanium";
      themeLight = "light";
      symbolPreset = "nerd";
    };
    interaction.setupWizard = false;
    providers.webSearch = "auto";
    aiGateway.apiKey = config.sops.placeholder.omp_ai_gateway_api_key;
  };

  home.stateVersion = "24.11";
}
