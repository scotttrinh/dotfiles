{ config, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf mkOption optionalAttrs types;

  cfg = config.mimoCode;

  removeNulls = lib.filterAttrsRecursive (_: value: value != null);
  optionalNonEmpty = name: value: lib.optionalAttrs (value != { }) { ${name} = value; };

  providerOptions =
    removeNulls
      {
        apiKey = cfg.auth.secret;
        baseURL = cfg.baseUrl;
        timeout = cfg.timeoutMs;
      }
    // cfg.provider.options;

  providerConfig =
    removeNulls
      {
        api = cfg.provider.api;
        name = cfg.provider.name;
        env = cfg.provider.env;
        id = cfg.provider.serializedId;
        npm = cfg.provider.npm;
        whitelist = cfg.provider.whitelist;
        blacklist = cfg.provider.blacklist;
      }
    // optionalNonEmpty "options" providerOptions
    // optionalNonEmpty "models" cfg.provider.models;

  settings = removeNulls (
    {
      "$schema" = cfg.schema;
      model = cfg.model;
      small_model = cfg.smallModel;
      enabled_providers = cfg.enabledProviders;
      disabled_providers = cfg.disabledProviders;
      provider = optionalAttrs (providerConfig != { }) {
        ${cfg.provider.id} = providerConfig;
      };
    }
    // cfg.settings
  );
in
{
  options.mimoCode = {
    enable = mkEnableOption "mimo-code";

    schema = mkOption {
      type = types.str;
      default = "https://opencode.ai/config.json";
      description = "JSON schema reference written to the MiMo-Code config.";
    };

    auth = {
      secret = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Authentication secret written to provider.options.apiKey.";
      };
    };

    baseUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Provider base URL written to provider.options.baseURL.";
    };

    timeoutMs = mkOption {
      type = types.nullOr (types.either types.ints.positive (types.enum [ false ]));
      default = null;
      description = "Provider request timeout in milliseconds, or false to disable timeout.";
    };

    model = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Default model in provider/model format.";
    };

    smallModel = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Small model in provider/model format.";
    };

    enabledProviders = mkOption {
      type = types.nullOr (types.listOf types.str);
      default = null;
      description = "Provider IDs to enable exclusively.";
    };

    disabledProviders = mkOption {
      type = types.nullOr (types.listOf types.str);
      default = null;
      description = "Provider IDs to disable.";
    };

    provider = {
      id = mkOption {
        type = types.str;
        default = "vercel";
        description = "MiMo-Code provider ID.";
      };

      serializedId = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional provider.id field to write inside the provider config.";
      };

      api = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Provider API compatibility name.";
      };

      name = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Human-readable provider name.";
      };

      env = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Environment variable names used by the provider.";
      };

      npm = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Provider npm package override.";
      };

      whitelist = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Model whitelist for the provider.";
      };

      blacklist = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Model blacklist for the provider.";
      };

      options = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Additional raw provider.options fields.";
      };

      models = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Provider model metadata and overrides.";
      };
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Additional raw MiMo-Code config fields merged into config.json.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.auth.secret != null || cfg.provider.options ? apiKey;
        message = "mimoCode.auth.secret must be set unless mimoCode.provider.options.apiKey is set.";
      }
    ];

    sops.templates."mimocode-config".content = builtins.toJSON settings;
    sops.templates."mimocode-config".path = "${config.home.homeDirectory}/.config/mimocode/config.json";
  };
}
