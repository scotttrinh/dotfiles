{
  config,
  lib,
  pkgs,
  ...
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

  settings = lib.recursiveUpdate (
    removeNulls {
      inherit (cfg) model;
      model_reasoning_effort = cfg.modelReasoningEffort;
      model_provider = cfg.modelProvider;
      openai_base_url = cfg.openaiBaseUrl;
      oss_provider = cfg.ossProvider;
      project_root_markers = cfg.projectRootMarkers;

      projects = builtins.listToAttrs (map trustedProject cfg.trustedProjects) // cfg.projects;

      notice = {
        fast_default_opt_out = cfg.notice.fastDefaultOptOut;
        model_migrations = cfg.notice.modelMigrations;
      };

      features = {
        default_mode_request_user_input = cfg.features.defaultModeRequestUserInput;
        multi_agent = cfg.features.multiAgent;
        prevent_idle_sleep = cfg.features.preventIdleSleep;
      };

      agents = {
        max_threads = cfg.agents.maxThreads;
        max_depth = cfg.agents.maxDepth;
      }
      // lib.mapAttrs (_: agent: {
        inherit (agent) description;
        config_file = agent.configFile;
      }) cfg.agents.roles;

      mcp_servers = cfg.mcpServers;

      skills.config = cfg.skills;

      tui = {
        status_line = cfg.tui.statusLine;
        model_availability_nux = cfg.tui.modelAvailabilityNux;
      };

      plugins = lib.mapAttrs (_: plugin: {
        enabled = plugin.enable;
      }) cfg.plugins;
    }
    // lib.optionalAttrs (cfg.modelProviders != { }) {
      model_providers = lib.mapAttrs (_: providerConfig) cfg.modelProviders;
    }
  ) cfg.extraSettings;

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
      type = types.str;
      default = "gpt-5.5";
      description = "Default Codex model.";
    };

    modelReasoningEffort = mkOption {
      type = nullable types.str;
      default = "medium";
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
        type = types.bool;
        default = true;
        description = "Opt out of the fast default notice.";
      };

      modelMigrations = mkOption {
        type = stringMap;
        default = {
          "gpt-5.2" = "gpt-5.2-codex";
        };
        description = "Model migration notice mapping.";
      };
    };

    features = {
      defaultModeRequestUserInput = mkOption {
        type = types.bool;
        default = true;
        description = "Enable request_user_input in default mode.";
      };

      multiAgent = mkOption {
        type = types.bool;
        default = true;
        description = "Enable multi-agent support.";
      };

      preventIdleSleep = mkOption {
        type = types.bool;
        default = true;
        description = "Prevent idle sleep while Codex is active.";
      };
    };

    agents = {
      maxThreads = mkOption {
        type = types.int;
        default = 4;
        description = "Maximum GSD agent threads.";
      };

      maxDepth = mkOption {
        type = types.int;
        default = 2;
        description = "Maximum GSD agent depth.";
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
        default = {
          gsd-codebase-mapper = {
            description = "Explores codebase and writes structured analysis documents. Spawned by map-codebase with a focus area (tech, arch, quality, concerns). Writes documents directly to reduce orchestrator context load.";
            configFile = "agents/gsd-codebase-mapper.toml";
          };
          gsd-debugger = {
            description = "Investigates bugs using scientific method, manages debug sessions, handles checkpoints. Spawned by /gsd:debug orchestrator.";
            configFile = "agents/gsd-debugger.toml";
          };
          gsd-executor = {
            description = "Executes GSD plans with atomic commits, deviation handling, checkpoint protocols, and state management. Spawned by execute-phase orchestrator or execute-plan command.";
            configFile = "agents/gsd-executor.toml";
          };
          gsd-integration-checker = {
            description = "Verifies cross-phase integration and E2E flows. Checks that phases connect properly and user workflows complete end-to-end.";
            configFile = "agents/gsd-integration-checker.toml";
          };
          gsd-nyquist-auditor = {
            description = "Fills Nyquist validation gaps by generating tests and verifying coverage for phase requirements";
            configFile = "agents/gsd-nyquist-auditor.toml";
          };
          gsd-phase-researcher = {
            description = "Researches how to implement a phase before planning. Produces RESEARCH.md consumed by gsd-planner. Spawned by /gsd:plan-phase orchestrator.";
            configFile = "agents/gsd-phase-researcher.toml";
          };
          gsd-plan-checker = {
            description = "Verifies plans will achieve phase goal before execution. Goal-backward analysis of plan quality. Spawned by /gsd:plan-phase orchestrator.";
            configFile = "agents/gsd-plan-checker.toml";
          };
          gsd-planner = {
            description = "Creates executable phase plans with task breakdown, dependency analysis, and goal-backward verification. Spawned by /gsd:plan-phase orchestrator.";
            configFile = "agents/gsd-planner.toml";
          };
          gsd-project-researcher = {
            description = "Researches domain ecosystem before roadmap creation. Produces files in .planning/research/ consumed during roadmap creation. Spawned by /gsd:new-project or /gsd:new-milestone orchestrators.";
            configFile = "agents/gsd-project-researcher.toml";
          };
          gsd-research-synthesizer = {
            description = "Synthesizes research outputs from parallel researcher agents into SUMMARY.md. Spawned by /gsd:new-project after 4 researcher agents complete.";
            configFile = "agents/gsd-research-synthesizer.toml";
          };
          gsd-roadmapper = {
            description = "Creates project roadmaps with phase breakdown, requirement mapping, success criteria derivation, and coverage validation. Spawned by /gsd:new-project orchestrator.";
            configFile = "agents/gsd-roadmapper.toml";
          };
          gsd-verifier = {
            description = "Verifies phase goal achievement through goal-backward analysis. Checks codebase delivers what phase promised, not just that tasks completed. Creates VERIFICATION.md report.";
            configFile = "agents/gsd-verifier.toml";
          };
        };
        description = "Configured Codex subagent roles.";
      };
    };

    mcpServers = mkOption {
      type = types.attrsOf toml.type;
      default = {
        linear.url = "https://mcp.linear.app/mcp";
      };
      description = "MCP server settings.";
    };

    modelProviders = mkOption {
      type = types.attrsOf providerType;
      default = { };
      description = "Custom Codex model providers.";
    };

    skills = mkOption {
      type = types.listOf toml.type;
      default =
        map
          (name: {
            path = "${home}/.codex/skills/${name}/SKILL.md";
            enabled = false;
          })
          [
            "gsd-add-tests"
            "gsd-add-phase"
            "gsd-add-todo"
            "gsd-audit-milestone"
            "gsd-check-todos"
            "gsd-cleanup"
            "gsd-complete-milestone"
            "gsd-debug"
            "gsd-discuss-phase"
            "gsd-execute-phase"
            "gsd-health"
            "gsd-help"
            "gsd-insert-phase"
            "gsd-join-discord"
            "gsd-list-phase-assumptions"
            "gsd-map-codebase"
            "gsd-new-milestone"
            "gsd-new-project"
            "gsd-pause-work"
            "gsd-plan-milestone-gaps"
            "gsd-plan-phase"
            "gsd-progress"
            "gsd-quick"
            "gsd-reapply-patches"
            "gsd-remove-phase"
            "gsd-research-phase"
            "gsd-resume-work"
            "gsd-set-profile"
            "gsd-settings"
            "gsd-update"
            "gsd-validate-phase"
            "gsd-verify-work"
          ]
        ++ [
          {
            path = "${home}/.agents/skills/linear/SKILL.md";
            enabled = false;
          }
          {
            path = "${home}/.codex/skills/.system/imagegen/SKILL.md";
            enabled = false;
          }
          {
            path = "${home}/.codex/skills/.system/openai-docs/SKILL.md";
            enabled = false;
          }
          {
            path = "${home}/.codex/skills/.system/plugin-creator/SKILL.md";
            enabled = false;
          }
          {
            path = "${home}/.codex/skills/.system/skill-installer/SKILL.md";
            enabled = false;
          }
        ];
      description = "Skill enablement config entries.";
    };

    tui = {
      statusLine = mkOption {
        type = types.listOf types.str;
        default = [
          "model-with-reasoning"
          "current-dir"
          "context-used"
        ];
        description = "Codex TUI status line segments.";
      };

      modelAvailabilityNux = mkOption {
        type = types.attrsOf types.int;
        default = {
          "gpt-5.5" = 4;
        };
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
      default = {
        "forward-roll@forward-roll-local".enable = true;
      };
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
        assertion = lib.all (
          providerName:
          !(builtins.elem providerName [
            "openai"
            "ollama"
            "lmstudio"
          ])
        ) (builtins.attrNames cfg.modelProviders);
        message = "codex.modelProviders cannot define reserved built-in provider IDs: openai, ollama, or lmstudio.";
      }
      {
        assertion = lib.all (
          provider:
          provider.auth == null
          || (
            provider.envKey == null
            && provider.experimentalBearerToken == null
            && provider.requiresOpenAIAuth == null
          )
        ) (builtins.attrValues cfg.modelProviders);
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
