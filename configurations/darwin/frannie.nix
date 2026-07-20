# See /modules/darwin/* for actual settings
# This file is just *top-level* configuration.
{ flake, lib, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
  secretiveSigningPublicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBHPTx4gM8No07bfV2bY1JdGrJKdq1/H+fn8rvHTxddxZFPrYR6uyKIbUmxNq59GpMinEoitaVHSA606DH4GuqVQ= Frannie-GitHub-Signing-Key @secretive.Scott’s-MacBook-Air.local";
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
    me.gitSigning = {
      publicKey = secretiveSigningPublicKey;
      agentKeyCommentPattern = "Frannie-GitHub-Signing-Key";
    };

    # Claude Code configuration using z.ai proxy
    claudeCode = {
      enable = true;
      # auth = {
      #   type = "apiKey";
      #   secret = config.sops.placeholder.claude_code_api_key;
      # };
      # baseUrl = "https://api.z.ai/api/anthropic";
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
      defaultModel  = "openai-codex/gpt-5.6-sol:low";
      planModel     = "openai-codex/gpt-5.6-sol:medium";
      slowModel     = "openai-codex/gpt-5.6-sol:max";
      taskModel     = "zai/glm-5.2:max";
      designerModel = "openai-codex/gpt-5.6-luna:max";
      visionModel   = "openai-codex/gpt-5.6-luna:max";
      commitModel   = "openai-codex/gpt-5.6-luna:none";
      smolModel     = "openai-codex/gpt-5.6-luna:medium";

      # Z.ai static credential (only provider needing one)
      modelProviders.zai = {
        apiKey = "!cat ${config.sops.secrets.codex_zai_coding_plan_api_key.path}";
      };

      # Retry fallback chains — no OpenAI model falls back to another OpenAI model
      model = {
        modelFallback = true;
        fallbackChains = {
          "openai-codex/gpt-5.6-sol"  = [ "anthropic/claude-opus-4-8" "google-antigravity/gemini-3.5-flash" ];
          "openai-codex/gpt-5.6-luna" = [ "zai/glm-5.2" "anthropic/claude-sonnet-5" "google-antigravity/gemini-3.5-flash" ];
          "zai/glm-5.2"               = [ "anthropic/claude-sonnet-5" "google-antigravity/gemini-3.5-flash" ];
        };
      };

      # Disable context promotion — rely on compaction
      context.promotionEnabled = false;

      # Per-agent model overrides
      tasks.agentModelOverrides = {
        reviewer   = "openai-codex/gpt-5.6-sol:medium";
        explore    = "openai-codex/gpt-5.6-luna:xhigh";
        librarian  = "openai-codex/gpt-5.6-luna:xhigh";
        oracle     = "openai-codex/gpt-5.6-sol:xhigh";
        task       = "zai/glm-5.2:max";
        plan       = "openai-codex/gpt-5.6-sol:medium";
        quick_task = "openai-codex/gpt-5.6-luna:high";
      };
    };

    # Declare the sops secret for this machine
    sops.secrets.claude_code_api_key = {
      key = "CLAUDE_CODE_API_KEY_FRANNIE";
      mode = "0400";
    };

    sops.secrets.codex_zai_coding_plan_api_key = {
      key = "CLAUDE_CODE_API_KEY_FRANNIE";
      mode = "0400";
    };
  };
  homebrew = {
    casks = [
      "orbstack"
      "openmtp"
    ];
  };
}
