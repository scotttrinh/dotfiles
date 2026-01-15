{ config, lib, ... }:
let
  cfg = config.claudeCode;
in
{
  options.claudeCode = {
    enable = lib.mkEnableOption "claude-code";

    statusLine = {
      enable = lib.mkEnableOption "custom statusLine";
    };

    auth = lib.mkOption {
      type = lib.types.submodule {
        options = {
          type = lib.mkOption {
            type = lib.types.enum [ "none" "oauth" "apiKey" ];
            default = "none";
            description = "Authentication type: none (passthrough), oauth (token-based), or apiKey (API key-based)";
          };
          secret = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "The sops placeholder for the authentication secret. Required when type is oauth or apiKey.";
          };
        };
      };
      default = { };
      description = "Authentication configuration for Claude Code";
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://api.anthropic.com";
      description = "Base URL for the Anthropic API";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "opus";
      description = "Default model to use (opus, sonnet, haiku, or a specific model ID)";
    };

    timeoutMs = lib.mkOption {
      type = lib.types.int;
      default = 120000;
      description = "API timeout in milliseconds";
    };

    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables to add to the Claude Code settings";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (cfg.auth.type == "none") || (cfg.auth.secret != null);
        message = "claudeCode.auth.secret must be set when auth.type is '${cfg.auth.type}'";
      }
    ];

    # Install statusLine script if enabled
    home.file = lib.mkIf cfg.statusLine.enable {
      ".claude/claude-statusline.sh" = {
        source = ./claude-statusline.sh;
        executable = true;
      };
    };

    # Build the settings.json as a proper JSON structure
    sops.templates."claude-settings".content = builtins.toJSON (
      {
        env = {
          ANTHROPIC_BASE_URL = cfg.baseUrl;
          API_TIMEOUT_MS = toString cfg.timeoutMs;
        }
        // (lib.optionalAttrs (cfg.auth.type == "oauth") {
          ANTHROPIC_AUTH_TOKEN = cfg.auth.secret;
        })
        // (lib.optionalAttrs (cfg.auth.type == "apiKey") {
          ANTHROPIC_API_KEY = cfg.auth.secret;
        })
        // cfg.extraEnv;
        model = cfg.model;
      }
      // (lib.optionalAttrs cfg.statusLine.enable {
        statusLine = {
          type = "command";
          command = "${config.home.homeDirectory}/.claude/claude-statusline.sh";
        };
      })
    );
    sops.templates."claude-settings".path = "${config.home.homeDirectory}/.claude/settings.json";
  };
}
