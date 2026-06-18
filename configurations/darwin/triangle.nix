# See /modules/darwin/* for actual settings
# This file is just *top-level* configuration.
{ flake
, lib
, pkgs
, ...
}:

let
  inherit (flake) inputs;
  inherit (inputs) self;
  secretiveSigningPublicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBOmJRCvBJwxxTm+LDnWseEJ861NISo8rpCA7Mj7NDdT1XfHCuUmDXAOEZw5NFv+MCnq4LzTyY2CNEH9dVqkm8fg= GitHub-Commit-Signing@secretive.triangle.local";

  # Define work repos to clone and setup
  # Each entry: { url, path, postClone (optional) }
  workRepos = [
    {
      url = "https://github.com/vercel/front";
      path = "$HOME/github.com/vercel/front";
      postClone = "pnpm install";
    }
  ];

  # Generate the activation script for cloning repos
  cloneRepoScript = repo: ''
    if [ ! -d "${repo.path}" ]; then
      echo "Cloning ${repo.url} to ${repo.path}..."
      mkdir -p "$(dirname "${repo.path}")"
      ${pkgs.git}/bin/git clone "${repo.url}" "${repo.path}" --depth 1
      ${lib.optionalString (repo ? postClone) ''
        echo "Running post-clone commands for ${repo.path}..."
        cd "${repo.path}" && ${repo.postClone}
      ''}
    else
      echo "Repository ${repo.path} already exists, skipping..."
    fi
  '';
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
  home-manager.users.scotttrinh =
    { lib, config, ... }:
    {
      me.gitSigning = {
        publicKey = secretiveSigningPublicKey;
      };

      # Declare the sops secret for this machine
      sops.secrets.claude_code_auth_token = {
        key = "CLAUDE_CODE_AUTH_TOKEN_TRIANGLE";
        mode = "0400";
      };

      sops.secrets.codex_ai_gateway_api_key = {
        key = "CODEX_AI_GATEWAY_API_KEY";
        mode = "0400";
      };

      claudeCode = {
        enable = true;
        auth = {
          type = "oauth";
          secret = config.sops.placeholder.claude_code_auth_token;
        };
        baseUrl = "https://ai-gateway.vercel.sh";
        model = "claude-fable-5";
        statusLine.enable = true;
        timeoutMs = 3000000; # 50 minutes
      };

      mimoCode = {
        enable = true;
        model = "vercel/deepseek/deepseek-v4-pro";
        smallModel = "vercel/deepseek/deepseek-v4-flash";
        enabledProviders = [ "vercel" "openai" ];
        providers.vercel = {
          auth.secret = config.sops.placeholder.claude_code_auth_token;
          timeoutMs = 3000000; # 50 minutes
          models = {
            "zai/glm-5.2".name = "GLM-5.2";
            "moonshotai/kimi-k2.7-code".name = "Kimi K2.7 Code";
            "minimax/minimax-m3".name = "MiniMax M3";
            "alibaba/qwen3.7-max".name = "Qwen3.7 Max";
            "deepseek/deepseek-v4-pro".name = "DeepSeek V4 Pro";
            "deepseek/deepseek-v4-flash".name = "DeepSeek V4 Flash";
          };
        };
      };

      codex = {
        modelProvider = "openai";
        aiGateway = {
          apiKeyFile = config.sops.secrets.codex_ai_gateway_api_key.path;
        };

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

      # Activation script to clone work repos
      # Runs during `nix run .#activate` / `home-manager switch`
      home.activation.cloneWorkRepos = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        echo "Setting up work repositories..."
        ${lib.concatMapStrings cloneRepoScript workRepos}
      '';
    };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  homebrew = {
    masApps = {
      OktaVerify = 490179405;
    };
    casks = [
      "slack"
      "cursor"
      "orbstack"
    ];
    brews = [
      "vercel-cli"
      "supabase"
    ];
  };
}
