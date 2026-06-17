{ flake }:
let
  pkgs = flake.inputs.nixpkgs.legacyPackages.aarch64-darwin;

  home = flake.inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      flake.inputs.sops-nix.homeManagerModules.sops
      ../modules/home/omp/default.nix
      {
        home = {
          username = "omp-test";
          homeDirectory = "/Users/omp-test";
          stateVersion = "26.05";
        };

        omp = {
          enable = true;
          aiGateway.enable = false;

          appearance = {
            themeDark = "custom";
            showImages = false;
          };
          model = {
            providerOrder = [ "custom" ];
            temperature = 0.25;
            retryEnabled = true;
          };
          interaction = {
            autoResume = true;
            approvalTimeout = 30;
          };
          context = {
            compactionEnabled = true;
            branchSummaryEnabled = true;
            ttsrEnabled = false;
          };
          memory = {
            commonEnabled = true;
            backend = "mnemopi";
          };
          files = {
            editMode = "hashline";
            lspEnabled = true;
          };
          shell = {
            path = "/bin/zsh";
            evalPython = true;
          };
          tools = {
            approvalMode = "ask";
            browserEnabled = false;
          };
          tasks = {
            planEnabled = true;
            maxConcurrency = 4;
            skillsEnabled = true;
          };
          providers = {
            disabled = [ "unused" ];
            redactSecrets = true;
          };

          settings = {
            temperature = 0.5;
            compaction.thresholdTokens = 1234;
          };
          extraConfig = {
            temperature = 0.75;
            startup.quiet = true;
          };

          modelProviders = {
            custom = {
              baseUrl = "https://example.invalid/v1";
              apiKey = "!secret-tool read custom";
              api = "openai-responses";
              headers.X-Command-Secret = "!secret-tool read header";
              compat = {
                supportsDeveloperRole = true;
                whenThinking.supportsStore = false;
              };
              models = [
                {
                  id = "reasoner";
                  name = "Reasoner";
                  reasoning = true;
                  thinking = {
                    mode = "effort";
                    efforts = [
                      "low"
                      "high"
                    ];
                  };
                  input = [
                    "text"
                    "image"
                  ];
                  contextWindow = 200000;
                  maxTokens = 32000;
                  contextPromotionTarget = "custom/reasoner-large";
                }
              ];
            };
            override-only = {
              headers.X-Test = "value";
              modelOverrides.bundled.name = "Renamed";
            };
            discovered = {
              baseUrl = "http://localhost:11434/v1";
              auth = "none";
              api = "openai-completions";
              discovery.type = "ollama";
            };
          };
          modelEquivalence = {
            overrides."custom/reasoner" = "gpt-5.5";
            exclude = [ "custom/preview" ];
          };
          extraModels.providers.custom.headers.X-Raw = "wins";

          keybindings."app.interrupt" = [
            "escape"
            "ctrl+c"
          ];
          themes.custom = {
            name = "custom";
            colors.accent = "#ffffff";
          };
          prompts = {
            appendSystem.text = "Keep the default prompt.";
            agents.text = "Repository instructions.";
          };
          agentFiles = {
            "commands/review.md".text = "Review the current changes.";
            "tools/check.sh" = {
              text = "#!/bin/sh\nexit 0\n";
              executable = true;
            };
            "skills/example" = {
              source = ../modules/home/omp;
              recursive = true;
            };
          };
        };
      }
    ];
  };

  configJson = builtins.fromJSON home.config.sops.templates.omp-config.content;
  modelsJson = builtins.fromJSON home.config.sops.templates.omp-models.content;
  files = home.config.home.file;
  failedAssertions = builtins.filter (assertion: !assertion.assertion) home.config.assertions;
in
assert failedAssertions == [ ];
assert configJson.temperature == 0.75;
assert configJson.compaction.enabled;
assert configJson.compaction.thresholdTokens == 1234;
assert !(configJson ? nullValue);
assert modelsJson.providers.custom.headers.X-Raw == "wins";
assert modelsJson.providers.discovered.discovery.type == "ollama";
assert modelsJson.providers.override-only.modelOverrides.bundled.name == "Renamed";
assert modelsJson.equivalence.overrides."custom/reasoner" == "gpt-5.5";
assert files.".omp/agent/keybindings.yml" ? text;
assert files.".omp/agent/themes/custom.json" ? text;
assert files.".omp/agent/APPEND_SYSTEM.md".text == "Keep the default prompt.";
assert files.".omp/agent/tools/check.sh".executable;
assert files.".omp/agent/skills/example".recursive;
{
  inherit configJson modelsJson;
  managedFiles = builtins.attrNames files;
}
