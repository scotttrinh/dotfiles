{ config
, lib
, pkgs
, ...
}:

let
  inherit (lib) mkIf mkOption types;

  cfg = config.codex;
  toml = pkgs.formats.toml { };
  home = config.home.homeDirectory;
  generatedConfig = toml.generate "codex-config.toml" settings;

  nullable = type: types.nullOr type;
  stringMap = types.attrsOf types.str;
  tomlScalar = types.oneOf [
    types.bool
    types.int
    types.float
    types.str
  ];

  removeNulls = lib.filterAttrsRecursive (_: value: value != null);
  optionalNonEmpty = name: value: lib.optionalAttrs (value != { }) { ${name} = value; };

  trustedProject = path: {
    name = path;
    value.trust_level = "trusted";
  };

  providerConfig =
    provider:
    removeNulls {
      inherit (provider) name;
      base_url = provider.baseUrl;
      env_key = provider.envKey;
      wire_api = provider.wireApi;
      http_headers = provider.httpHeaders;
      env_http_headers = provider.envHttpHeaders;
      query_params = provider.queryParams;
      request_max_retries = provider.requestMaxRetries;
      stream_max_retries = provider.streamMaxRetries;
      stream_idle_timeout_ms = provider.streamIdleTimeoutMs;
      experimental_bearer_token = provider.experimentalBearerToken;
      requires_openai_auth = provider.requiresOpenAIAuth;
      auth =
        if provider.auth == null then
          null
        else
          removeNulls {
            inherit (provider.auth) command args;
            timeout_ms = provider.auth.timeoutMs;
            refresh_interval_ms = provider.auth.refreshIntervalMs;
          };
      aws =
        if provider.aws == null then
          null
        else
          removeNulls {
            inherit (provider.aws) profile region;
          };
    };

  noticeSettings =
    removeNulls
      {
        fast_default_opt_out = cfg.notice.fastDefaultOptOut;
      }
    // lib.optionalAttrs (cfg.notice.modelMigrations != { }) {
      model_migrations = cfg.notice.modelMigrations;
    };

  featuresSettings = removeNulls {
    default_mode_request_user_input = cfg.features.defaultModeRequestUserInput;
    multi_agent = cfg.features.multiAgent;
    prevent_idle_sleep = cfg.features.preventIdleSleep;
  };

  agentRoleSettings = lib.mapAttrs
    (_: agent: {
      inherit (agent) description;
      config_file = agent.configFile;
    })
    cfg.agents.roles;

  agentSettings =
    removeNulls
      {
        max_threads = cfg.agents.maxThreads;
        max_depth = cfg.agents.maxDepth;
      }
    // agentRoleSettings;

  tuiSettings =
    removeNulls
      {
        status_line = cfg.tui.statusLine;
      }
    // lib.optionalAttrs (cfg.tui.modelAvailabilityNux != { }) {
      model_availability_nux = cfg.tui.modelAvailabilityNux;
    };

  settings = lib.recursiveUpdate
    (
      removeNulls
        {
          inherit (cfg) model;
          model_reasoning_effort = cfg.modelReasoningEffort;
          model_provider = cfg.modelProvider;
          openai_base_url = cfg.openaiBaseUrl;
          oss_provider = cfg.ossProvider;
          project_root_markers = cfg.projectRootMarkers;
        }
      // optionalNonEmpty "projects" ((builtins.listToAttrs (map trustedProject cfg.trustedProjects)) // cfg.projects)
      // optionalNonEmpty "notice" noticeSettings
      // optionalNonEmpty "features" featuresSettings
      // optionalNonEmpty "agents" agentSettings
      // optionalNonEmpty "mcp_servers" cfg.mcpServers
      // lib.optionalAttrs (cfg.skills != [ ]) {
        skills.config = cfg.skills;
      }
      // optionalNonEmpty "tui" tuiSettings
      // optionalNonEmpty "plugins" (lib.mapAttrs
        (_: plugin: {
          enabled = plugin.enable;
        })
        cfg.plugins)
      // lib.optionalAttrs (cfg.modelProviders != { }) {
        model_providers = lib.mapAttrs (_: providerConfig) cfg.modelProviders;
      }
    )
    cfg.extraSettings;

  providerType = types.submodule {
    options = {
      name = mkOption {
        type = nullable types.str;
        default = null;
        description = "Display name for the model provider.";
      };

      baseUrl = mkOption {
        type = nullable types.str;
        default = null;
        description = "Base URL for the provider API.";
      };

      envKey = mkOption {
        type = nullable types.str;
        default = null;
        description = "Environment variable containing the provider API key.";
      };

      wireApi = mkOption {
        type = nullable types.str;
        default = null;
        description = "Wire API used by the provider, for example responses.";
      };

      httpHeaders = mkOption {
        type = stringMap;
        default = { };
        description = "Static HTTP headers sent to the provider.";
      };

      envHttpHeaders = mkOption {
        type = stringMap;
        default = { };
        description = "HTTP headers whose values are read from environment variables.";
      };

      queryParams = mkOption {
        type = types.attrsOf tomlScalar;
        default = { };
        description = "Query parameters sent to the provider.";
      };

      requestMaxRetries = mkOption {
        type = nullable types.int;
        default = null;
        description = "Maximum retries for non-streaming requests.";
      };

      streamMaxRetries = mkOption {
        type = nullable types.int;
        default = null;
        description = "Maximum retries for streaming requests.";
      };

      streamIdleTimeoutMs = mkOption {
        type = nullable types.int;
        default = null;
        description = "Stream idle timeout in milliseconds.";
      };

      experimentalBearerToken = mkOption {
        type = nullable types.str;
        default = null;
        description = "Experimental static bearer token for the provider.";
      };

      requiresOpenAIAuth = mkOption {
        type = nullable types.bool;
        default = null;
        description = "Whether the provider requires OpenAI authentication.";
      };

      auth = mkOption {
        type = nullable (
          types.submodule {
            options = {
              command = mkOption {
                type = types.str;
                description = "Command that prints a bearer token to stdout.";
              };

              args = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Arguments passed to the auth command.";
              };

              timeoutMs = mkOption {
                type = nullable types.int;
                default = null;
                description = "Auth command timeout in milliseconds.";
              };

              refreshIntervalMs = mkOption {
                type = nullable types.int;
                default = null;
                description = "How often Codex refreshes the command-backed token.";
              };
            };
          }
        );
        default = null;
        description = "Command-backed bearer-token authentication.";
      };

      aws = mkOption {
        type = nullable (
          types.submodule {
            options = {
              profile = mkOption {
                type = nullable types.str;
                default = null;
                description = "AWS profile for the amazon-bedrock provider.";
              };

              region = mkOption {
                type = nullable types.str;
                default = null;
                description = "AWS Bedrock region.";
              };
            };
          }
        );
        default = null;
        description = "AWS configuration for the amazon-bedrock provider.";
      };
    };
  };
in
{
  options.codex = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to install Codex and manage its global config.toml with Home Manager.";
    };

    package = mkOption {
      type = nullable types.package;
      default = null;
      description = "Codex package to install. Set to null to manage only configuration.";
    };

    model = mkOption {
      type = nullable types.str;
      default = null;
      description = "Default Codex model.";
    };

    modelReasoningEffort = mkOption {
      type = nullable types.str;
      default = null;
      description = "Default model reasoning effort.";
    };

    modelProvider = mkOption {
      type = nullable types.str;
      default = null;
      description = "Model provider ID to use for the default model.";
    };

    openaiBaseUrl = mkOption {
      type = nullable types.str;
      default = null;
      description = "Base URL override for the built-in OpenAI provider.";
    };

    ossProvider = mkOption {
      type = nullable types.str;
      default = null;
      description = "Default local provider used with codex --oss.";
    };

    projectRootMarkers = mkOption {
      type = nullable (types.listOf types.str);
      default = null;
      description = "Markers Codex uses to discover a project root.";
    };

    trustedProjects = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Project paths to mark as trusted.";
    };

    projects = mkOption {
      type = types.attrsOf toml.type;
      default = { };
      description = "Raw per-project Codex settings keyed by absolute project path.";
    };

    notice = {
      fastDefaultOptOut = mkOption {
        type = nullable types.bool;
        default = null;
        description = "Opt out of the fast default notice.";
      };

      modelMigrations = mkOption {
        type = stringMap;
        default = { };
        description = "Model migration notice mapping.";
      };
    };

    features = {
      defaultModeRequestUserInput = mkOption {
        type = nullable types.bool;
        default = null;
        description = "Enable request_user_input in default mode.";
      };

      multiAgent = mkOption {
        type = nullable types.bool;
        default = null;
        description = "Enable multi-agent support.";
      };

      preventIdleSleep = mkOption {
        type = nullable types.bool;
        default = null;
        description = "Prevent idle sleep while Codex is active.";
      };
    };

    agents = {
      maxThreads = mkOption {
        type = nullable types.int;
        default = null;
        description = "Maximum Codex agent threads.";
      };

      maxDepth = mkOption {
        type = nullable types.int;
        default = null;
        description = "Maximum Codex agent depth.";
      };

      roles = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              description = mkOption {
                type = types.str;
                description = "Agent role description.";
              };

              configFile = mkOption {
                type = types.str;
                description = "Agent role config file path, relative to ~/.codex.";
              };
            };
          }
        );
        default = { };
        description = "Configured Codex subagent roles.";
      };
    };

    mcpServers = mkOption {
      type = types.attrsOf toml.type;
      default = { };
      description = "MCP server settings.";
    };

    modelProviders = mkOption {
      type = types.attrsOf providerType;
      default = { };
      description = "Custom Codex model providers.";
    };

    skills = mkOption {
      type = types.listOf toml.type;
      default = [ ];
      description = "Skill enablement config entries.";
    };

    tui = {
      statusLine = mkOption {
        type = nullable (types.listOf types.str);
        default = null;
        description = "Codex TUI status line segments.";
      };

      modelAvailabilityNux = mkOption {
        type = types.attrsOf types.int;
        default = { };
        description = "Model availability notice state.";
      };
    };

    plugins = mkOption {
      type = types.attrsOf (
        types.submodule {
          options.enable = mkOption {
            type = types.bool;
            default = true;
            description = "Whether this Codex plugin is enabled.";
          };
        }
      );
      default = { };
      description = "Codex plugin enablement settings.";
    };

    extraSettings = mkOption {
      type = toml.type;
      default = { };
      description = "Additional raw TOML settings merged into the generated Codex config.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all
          (
            providerName:
              !(builtins.elem providerName [
                "openai"
                "ollama"
                "lmstudio"
              ])
          )
          (builtins.attrNames cfg.modelProviders);
        message = "codex.modelProviders cannot define reserved built-in provider IDs: openai, ollama, or lmstudio.";
      }
      {
        assertion = lib.all
          (
            provider:
            provider.auth == null
            || (
              provider.envKey == null
              && provider.experimentalBearerToken == null
              && provider.requiresOpenAIAuth == null
            )
          )
          (builtins.attrValues cfg.modelProviders);
        message = "codex.modelProviders entries with command-backed auth cannot also set envKey, experimentalBearerToken, or requiresOpenAIAuth.";
      }
    ];

    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      codex_dir="${home}/.codex"
      codex_config="$codex_dir/config.toml"
      codex_backup="$codex_dir/config.toml.pre-nix"

      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$codex_dir"

      if [ -e "$codex_config" ] && [ ! -e "$codex_backup" ] && ! ${pkgs.diffutils}/bin/cmp -s ${generatedConfig} "$codex_config"; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp "$codex_config" "$codex_backup"
      fi

      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0600 ${generatedConfig} "$codex_config"
    '';
  };
}
