# See /modules/darwin/* for actual settings
# This file is just *top-level* configuration.
{ flake, lib, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
  secretiveSigningPublicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBHPTx4gM8No07bfV2bY1JdGrJKdq1/H+fn8rvHTxddxZFPrYR6uyKIbUmxNq59GpMinEoitaVHSA606DH4GuqVQ= Frannie-GitHub-Signing-Key @secretive.Scott’s-MacBook-Air.local";
  # Vercel AI Gateway exposed to OMP as a plain OpenAI-responses provider.
  # Per-model context/output/cost/modality metadata sourced from models.dev (2026-07-31).
  gatewayModels = [
    {
      id = "openai/gpt-5.6-sol";
      name = "GPT 5.6 Sol";
      contextWindow = 1050000;
      maxTokens = 128000;
      input = [
        "text"
        "image"
      ];
      cost = {
        input = 5;
        output = 30;
        cacheRead = 0.5;
        cacheWrite = 6.25;
      };
    }
    {
      id = "openai/gpt-5.6-luna";
      name = "GPT 5.6 Luna";
      contextWindow = 1050000;
      maxTokens = 128000;
      input = [
        "text"
        "image"
      ];
      cost = {
        input = 0.2;
        output = 1.2;
        cacheRead = 0.02;
        cacheWrite = 0.25;
      };
    }
    {
      id = "google/gemini-3.7-flash";
      name = "Gemini 3.7 Flash";
      contextWindow = 1048576;
      maxTokens = 65536;
      input = [
        "text"
        "image"
      ];
      cost = {
        input = 1.5;
        output = 7.5;
        cacheRead = 0.15;
        cacheWrite = 0;
      };
    }
    {
      id = "google/gemini-3.6-flash";
      name = "Gemini 3.6 Flash";
      contextWindow = 1048576;
      maxTokens = 65536;
      input = [
        "text"
        "image"
      ];
      cost = {
        input = 1.5;
        output = 7.5;
        cacheRead = 0.15;
        cacheWrite = 0;
      };
    }
    {
      id = "deepseek/deepseek-v4-pro";
      name = "DeepSeek V4 Pro";
      contextWindow = 1000000;
      maxTokens = 384000;
      input = [ "text" ];
      cost = {
        input = 0.435;
        output = 0.87;
        cacheRead = 0.003625;
        cacheWrite = 0;
      };
    }
    {
      id = "deepseek/deepseek-v4-flash-0731";
      name = "DeepSeek V4 Flash";
      contextWindow = 1000000;
      maxTokens = 384000;
      input = [ "text" ];
      cost = {
        input = 0.14;
        output = 0.28;
        cacheRead = 0.0028;
        cacheWrite = 0;
      };
    }
    {
      id = "xai/grok-4.5";
      name = "Grok 4.5";
      contextWindow = 500000;
      maxTokens = 500000;
      input = [
        "text"
        "image"
      ];
      cost = {
        input = 2;
        output = 6;
        cacheRead = 0.3;
        cacheWrite = 0;
      };
    }
  ];
  gatewayModel = m: {
    inherit (m)
      id
      name
      contextWindow
      maxTokens
      input
      cost
      ;
    api = "openai-responses";
    reasoning = true;
    compat = {
      supportsDeveloperRole = true;
      supportsReasoningEffort = true;
      supportsStore = true;
      maxTokensField = "max_completion_tokens";
    };
  };
in
{
  imports = [
    self.darwinModules.default
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  networking.hostName = "frannie";

  system.primaryUser = "scotttrinh";

  # Automatically move old dotfiles out of the way
  #
  # Note that home-manager is not very smart, if this backup file already exists it
  # will complain "Existing file .. would be clobbered by backing up". To mitigate this,
  # we try to use as unique a backup file extension as possible.
  home-manager.backupFileExtension = "nixos-unified-template-backup";

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # Machine-specific home-manager configuration
  home-manager.users.scotttrinh = { lib, config, pkgs, ... }: {
    sops.defaultSopsFile = ../../secrets/frannie.yaml;

    sops.secrets.emacs_authinfo = {
      key = "EMACS_AUTHINFO";
      path = "${config.home.homeDirectory}/.authinfo";
      mode = "0400";
    };

    me.gitSigning = {
      publicKey = secretiveSigningPublicKey;
      agentKeyCommentPattern = "Frannie-GitHub-Signing-Key";
    };

    # Claude Code configuration using z.ai proxy
    claudeCode = {
      enable = true;
      model = "opus";
      timeoutMs = 3000000; # 50 minutes
    };

    mimoCode = {
      enable = true;
      model = "zai-coding-plan/glm-5.2";
      enabledProviders = [ "zai-coding-plan" "openai" ];
      providers.openai.models."gpt-5.5-codex" = {
        id = "gpt-5.5";
        name = "GPT-5.5";
      };
    };

    codex = {
      enable = true;

      # Switch the active provider by changing this single line:
      #   "openai"          -> native bundled Codex models (gpt-5.5, gpt-5.4-mini, ...)
      #   "zai-coding-plan" -> z.ai GLM Coding Plan (glm-5.2)
      modelProvider = "openai";

      # z.ai key stays wired so switching to "zai-coding-plan" needs no other change.
      zaiCodingPlan.apiKeyFile = config.sops.secrets.codex_zai_coding_plan_api_key.path;

      notice = {
        fastDefaultOptOut = true;
        modelMigrations = {
          "gpt-5.2" = "gpt-5.2-codex";
        };
      };

      features = {
        defaultModeRequestUserInput = true;
        multiAgent = true;
        preventIdleSleep = true;
      };

      agents = {
        maxDepth = 2;
      };

      mcpServers = {
        linear.url = "https://mcp.linear.app/mcp";
      };

      skills = [
        {
          path = "${config.home.homeDirectory}/.agents/skills/linear/SKILL.md";
          enabled = false;
        }
        {
          path = "${config.home.homeDirectory}/.codex/skills/.system/imagegen/SKILL.md";
          enabled = false;
        }
        {
          path = "${config.home.homeDirectory}/.codex/skills/.system/openai-docs/SKILL.md";
          enabled = false;
        }
        {
          path = "${config.home.homeDirectory}/.codex/skills/.system/plugin-creator/SKILL.md";
          enabled = false;
        }
        {
          path = "${config.home.homeDirectory}/.codex/skills/.system/skill-installer/SKILL.md";
          enabled = false;
        }
      ];

      tui = {
        statusLine = [
          "model-with-reasoning"
          "current-dir"
          "context-used"
        ];
        modelAvailabilityNux = {
          "gpt-5.5" = 4;
        };
      };

      plugins = {
        "forward-roll@forward-roll-local".enable = true;
      };

      trustedProjects = [
        "${config.home.homeDirectory}/github.com/vercel"
        "${config.home.homeDirectory}/github.com/vercel/vercel-py"
        "${config.home.homeDirectory}/github.com/scotttrinh/changing"
        "${config.home.homeDirectory}/github.com/scotttrinh/vpi"
        "${config.home.homeDirectory}/.codex"
        "${config.home.homeDirectory}/github.com/scotttrinh/subreq"
        "${config.home.homeDirectory}/github.com/scotttrinh/dotfiles"
        "${config.home.homeDirectory}/github.com/scotttrinh/forward-roll"
        "${config.home.homeDirectory}/.config/doom"
        "${config.home.homeDirectory}/github.com/scotttrinh/jj"
        "${config.home.homeDirectory}/github.com/scotttrinh/org"
        "${config.home.homeDirectory}/github.com/openai-early-access/openai-agents-python-preview"
        "${config.home.homeDirectory}/github.com/scotttrinh/hermes-agent"
        "${config.home.homeDirectory}/github.com/scotttrinh/chano"
        "${config.home.homeDirectory}/github.com/vercel-labs/openai-agents-fastapi-starter"
        "${config.home.homeDirectory}/github.com/scotttrinh/bw-to-op"
        "${config.home.homeDirectory}/github.com/scotttrinh/mru-tab-switcher"
      ];
    };

    omp = {
      enable = true;

      # Model roles
      defaultModel = "openai-codex/gpt-5.6-luna:high";
      smolModel = "openai-codex/gpt-5.6-luna:medium";
      planModel = "openai-codex/gpt-5.6-sol:medium";
      slowModel = "openai-codex/gpt-5.6-sol:max";
      taskModel = "openai-codex/gpt-5.6-luna:medium";
      designerModel = "openai-codex/gpt-5.6-luna:max";
      visionModel = "openai-codex/gpt-5.6-luna:max";
      commitModel = "openai-codex/gpt-5.6-luna:none";

      # Z.ai static credential (only provider needing one)
      modelProviders.zai = {
        apiKey = "!cat ${config.sops.secrets.codex_zai_coding_plan_api_key.path}";
      };
      modelProviders.ai-gateway = {
        baseUrl = "https://ai-gateway.vercel.sh/v1";
        apiKey = config.sops.placeholder.ai_gateway_api_key;
        api = "openai-responses";
        auth = "apiKey";
        authHeader = true;
        models = map gatewayModel gatewayModels;
      };

      model = {
        modelFallback = true;
        fallbackChains = {
          "openai-codex/gpt-5.6-sol" = [ "anthropic/claude-opus-5" ];
          "openai-codex/gpt-5.6-luna" = [ "zai/glm-5.2" "google-antigravity/gemini-3.6-flash" "ai-gateway/deepseek/deepseek-v4-flash" ];
        };
      };

      # Disable context promotion — rely on compaction
      context.promotionEnabled = false;
    };

    sops.secrets.codex_zai_coding_plan_api_key = {
      key = "ZAI_CODING_PLAN_API_KEY";
      mode = "0400";
    };
    sops.secrets.ai_gateway_api_key = {
      key = "AI_GATEWAY_API_KEY";
      mode = "0400";
    };

    home.packages = [
      (pkgs.writeShellScriptBin "fx" ''
        export AI_GATEWAY_API_KEY="$(cat ${config.sops.secrets.ai_gateway_api_key.path})"
        exec ${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.fx} "$@"
      '')
    ];
  };
  homebrew = {
    casks = [
      "orbstack"
      "openmtp"
    ];
    brews = [
      "vercel-cli"
    ];
  };
}
