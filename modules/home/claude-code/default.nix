{ config, lib, ... }:
let
  cfg = config.claudeCode;
in
{
  options.claudeCode = {
    enable = lib.mkEnableOption "claude-code";

    apiKeySecret = lib.mkOption {
      type = lib.types.str;
      description = "The sops placeholder for the API key (e.g., config.sops.placeholder.anthropic_api_key)";
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
    # Build the settings.json as a proper JSON structure
    sops.templates."claude-settings".content = builtins.toJSON (
      {
        env = {
          ANTHROPIC_AUTH_TOKEN = cfg.apiKeySecret;
          ANTHROPIC_BASE_URL = cfg.baseUrl;
          API_TIMEOUT_MS = toString cfg.timeoutMs;
        } // cfg.extraEnv;
        model = cfg.model;
      }
    );
    sops.templates."claude-settings".path = "${config.home.homeDirectory}/.claude/settings.json";
  };
}
