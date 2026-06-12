{ config, lib, ... }:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.mimoCode;

  removeNulls = lib.filterAttrsRecursive (_: value: value != null);
  optionalNonEmpty = name: value: lib.optionalAttrs (value != { }) { ${name} = value; };

  providerConfig =
    provider:
    let
      providerOptions =
        removeNulls {
          apiKey = provider.auth.secret;
          baseURL = provider.baseUrl;
          timeout = provider.timeoutMs;
        }
        // provider.options;
    in
    removeNulls {
      inherit (provider)
        api
        env
        name
        npm
        whitelist
        blacklist
        ;
      id = provider.serializedId;
    }
    // optionalNonEmpty "options" providerOptions
    // optionalNonEmpty "models" provider.models;

  providerConfigs = lib.mapAttrs (_: provider: providerConfig provider) cfg.providers;

  settings = removeNulls (
    {
      "$schema" = cfg.schema;
      model = cfg.model;
      small_model = cfg.smallModel;
      enabled_providers = cfg.enabledProviders;
      disabled_providers = cfg.disabledProviders;
      provider = if providerConfigs == { } then null else providerConfigs;
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

    providers = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            auth.secret = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Authentication secret written to this provider's options.apiKey.
                Leave unset to use environment or CLI-managed credentials.
              '';
            };

            baseUrl = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Provider base URL written to options.baseURL.";
            };

            timeoutMs = mkOption {
              type = types.nullOr (types.either types.ints.positive (types.enum [ false ]));
              default = null;
              description = "Provider request timeout in milliseconds, or false to disable timeout.";
            };

            serializedId = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Optional provider.id field written inside the provider config.";
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
        }
      );
      default = { };
      description = "Provider configuration keyed by MiMo-Code provider ID.";
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Additional raw MiMo-Code config fields merged into config.json.";
    };
  };

  config = mkIf cfg.enable {
    sops.templates."mimocode-config".content = builtins.toJSON settings;
    sops.templates."mimocode-config".path = "${config.home.homeDirectory}/.config/mimocode/config.json";
  };
}
