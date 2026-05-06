{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.omp;

  json = pkgs.formats.json { };

  gatewayModelType = types.submodule {
    options = {
      id = mkOption {
        type = types.str;
        description = "Vercel AI Gateway model ID, including provider prefix.";
      };

      name = mkOption {
        type = types.str;
        description = "Display name shown by omp.";
      };

      contextWindow = mkOption {
        type = types.int;
        default = 400000;
        description = "Model context window used by omp metadata.";
      };

      maxTokens = mkOption {
        type = types.int;
        default = 128000;
        description = "Maximum output tokens used by omp metadata.";
      };

      reasoning = mkOption {
        type = types.bool;
        default = true;
        description = "Whether omp should treat this model as reasoning-capable.";
      };

      input = mkOption {
        type = types.listOf types.str;
        default = [
          "text"
          "image"
        ];
        description = "Input modalities supported by the model.";
      };
    };
  };

  defaultGatewayModels = [
    {
      id = "openai/gpt-5.5";
      name = "GPT-5.5";
    }
    {
      id = "openai/gpt-5.4-mini";
      name = "GPT-5.4 Codex";
    }
    {
      id = "google/gemini-3.1-pro-preview";
      name = "Gemini 3.1 Pro";
    }
    {
      id = "xai/grok-4.3";
      name = "Grok 4.3";
    }
    {
      id = "moonshotai/kimi-k2.6";
      name = "Kimi K2.6";
    }
    {
      id = "deepseek/deepseek-v4-pro";
      name = "DeepSeek V4 Pro";
    }
  ];

  gatewayModelConfig = model: {
    inherit (model)
      id
      name
      reasoning
      input
      contextWindow
      maxTokens
      ;
    api = "openai-responses";
    cost = {
      input = 0;
      output = 0;
      cacheRead = 0;
      cacheWrite = 0;
    };
    compat = {
      supportsDeveloperRole = true;
      supportsReasoningEffort = true;
      supportsStore = true;
      maxTokensField = "max_completion_tokens";
    };
  };

  configFile = json.generate "omp-config.yml" (
    {
      modelRoles = {
        default = cfg.defaultModel;
        plan = cfg.planModel;
        smol = cfg.smolModel;
        commit = cfg.commitModel;
      };
      enabledModels = cfg.enabledModels;
      modelProviderOrder = [ cfg.aiGateway.providerId ];
    }
    // cfg.extraConfig
  );

  modelsConfig = {
    providers.${cfg.aiGateway.providerId} = {
      baseUrl = cfg.aiGateway.baseUrl;
      apiKey = cfg.aiGateway.apiKey;
      api = "openai-responses";
      auth = "apiKey";
      authHeader = true;
      models = map gatewayModelConfig cfg.aiGateway.models;
    };
  }
  // cfg.extraModels;
in
{
  options.omp = {
    enable = mkEnableOption "oh-my-pi";

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = "oh-my-pi package to install. Set to null to manage only configuration.";
    };

    defaultModel = mkOption {
      type = types.str;
      default = "ai-gateway/openai/gpt-5.5";
      description = "Default omp model selector.";
    };

    planModel = mkOption {
      type = types.str;
      default = cfg.defaultModel;
      description = "omp model selector used for planning.";
    };

    smolModel = mkOption {
      type = types.str;
      default = "ai-gateway/openai/gpt-5.4-codex";
      description = "omp model selector used for small tasks.";
    };

    commitModel = mkOption {
      type = types.str;
      default = cfg.smolModel;
      description = "omp model selector used for commit generation.";
    };

    enabledModels = mkOption {
      type = types.listOf types.str;
      default = [ "ai-gateway/*" ];
      description = "omp enabled model patterns.";
    };

    aiGateway = {
      providerId = mkOption {
        type = types.str;
        default = "ai-gateway";
        description = "Provider ID used in omp models.yml for Vercel AI Gateway.";
      };

      baseUrl = mkOption {
        type = types.str;
        default = "https://ai-gateway.vercel.sh/v1";
        description = "Vercel AI Gateway OpenAI-compatible API base URL.";
      };

      apiKey = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Vercel AI Gateway API key or sops placeholder written directly to omp models.yml.";
      };

      models = mkOption {
        type = types.listOf gatewayModelType;
        default = defaultGatewayModels;
        description = "Model metadata exposed to omp for Vercel AI Gateway.";
      };
    };

    extraConfig = mkOption {
      type = json.type;
      default = { };
      description = "Additional raw settings merged into ~/.omp/agent/config.yml.";
    };

    extraModels = mkOption {
      type = json.type;
      default = { };
      description = "Additional raw settings merged into ~/.omp/agent/models.yml.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.aiGateway.apiKey != null;
        message = "omp.aiGateway.apiKey must be set to statically configure omp for Vercel AI Gateway.";
      }
    ];

    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.file.".omp/agent/config.yml".source = configFile;

    sops.templates."omp-models".content = builtins.toJSON modelsConfig;
    sops.templates."omp-models".path = "${config.home.homeDirectory}/.omp/agent/models.yml";
  };
}
