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

  modelCatalogUsesBundled = lib.any (m: m.inheritFromBundled != null) cfg.modelCatalog;

  rawModelCatalogJson = builtins.toJSON {
    models = map modelCatalogEntry cfg.modelCatalog;
  };

  generatedModelCatalog =
    if !modelCatalogUsesBundled then
      pkgs.writeText "codex-model-catalog.json" rawModelCatalogJson
    else
      pkgs.runCommand "codex-model-catalog.json"
        {
          nativeBuildInputs = [
            pkgs.jq
            cfg.package
          ];
          rawCatalog = rawModelCatalogJson;
          passAsFile = [ "rawCatalog" ];
        }
        ''
          export HOME="$TMPDIR"
          bundled=$(codex debug models --bundled)

          jq --argjson bundled "$bundled" '
            ($bundled.models | map({key: .slug, value: .}) | from_entries) as $b
            | .models |= map(
                if .inherit_from_bundled then
                  .inherit_from_bundled as $key
                  | ($b[$key] // error("codex.modelCatalog: inheritFromBundled slug \"" + $key + "\" is not present in the bundled codex catalog")) as $src
                  | ({
                      base_instructions: $src.base_instructions,
                      truncation_policy: $src.truncation_policy,
                      experimental_supported_tools: $src.experimental_supported_tools,
                      model_messages: $src.model_messages
                    }
                    | with_entries(select(.value != null))) + .
                  | del(.inherit_from_bundled)
                else . end
              )
          ' "$rawCatalogPath" > "$out"
        '';

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

  openAIReasoningLevels = [
    {
      effort = "low";
      description = "Fast responses with lighter reasoning";
    }
    {
      effort = "medium";
      description = "Balances speed and reasoning depth for everyday tasks";
    }
    {
      effort = "high";
      description = "Greater reasoning depth for complex problems";
    }
    {
      effort = "xhigh";
      description = "Extra high reasoning depth for complex problems";
    }
  ];

  defaultReasoningLevels = [
    {
      effort = "medium";
      description = "Default reasoning depth";
    }
  ];

  aiGatewayModelCatalog = [
    {
      slug = "openai/gpt-5.5";
      inheritFromBundled = "gpt-5.5";
      displayName = "GPT-5.5";
      description = "Frontier model for complex coding, research, and real-world work.";
      defaultReasoningLevel = "medium";
      supportedReasoningLevels = openAIReasoningLevels;
      priority = 0;
      additionalSpeedTiers = [
        "priority"
        "fast"
      ];
    }
    {
      slug = "openai/gpt-5.4-mini";
      inheritFromBundled = "gpt-5.4-mini";
      displayName = "GPT-5.4 Mini";
      description = "Small, fast, and cost-efficient model for simpler coding tasks.";
      defaultReasoningLevel = "medium";
      supportedReasoningLevels = openAIReasoningLevels;
      priority = 1;
      additionalSpeedTiers = [ "fast" ];
    }
    {
      slug = "moonshotai/kimi-k2.6";
      inheritFromBundled = "gpt-5.5";
      displayName = "Kimi K2.6";
      description = "Moonshot AI model served through Vercel AI Gateway.";
      defaultReasoningLevel = "medium";
      supportedReasoningLevels = defaultReasoningLevels;
      priority = 2;
    }
    {
      slug = "deepseek/deepseek-v4-pro";
      inheritFromBundled = "gpt-5.5";
      displayName = "DeepSeek V4 Pro";
      description = "DeepSeek model served through Vercel AI Gateway.";
      defaultReasoningLevel = "medium";
      supportedReasoningLevels = defaultReasoningLevels;
      priority = 3;
    }
  ];

  aiGatewayProvider = removeNulls {
    name = "Vercel AI Gateway";
    baseUrl = "https://ai-gateway.vercel.sh/v1";
    wireApi = "responses";
    auth =
      if cfg.aiGateway.apiKeyFile == null then
        null
      else
        {
          command = "${pkgs.coreutils}/bin/cat";
          args = [ cfg.aiGateway.apiKeyFile ];
          timeoutMs = 5000;
          refreshIntervalMs = 300000;
        };
  };

  zaiCodingPlanModelCatalog = [
    {
      slug = "glm-5.2";
      inheritFromBundled = "gpt-5.5";
      displayName = "GLM-5.2";
      description = "z.ai GLM Coding Plan model for Codex.";
      defaultReasoningLevel = "medium";
      supportedReasoningLevels = defaultReasoningLevels;
      contextWindow = 1000000;
      inputModalities = [ "text" ];
      supportsImageDetailOriginal = false;
      priority = 0;
    }
  ];

  zaiCodingPlanProvider = removeNulls {
    name = "z.ai GLM Coding Plan";
    baseUrl = "https://api.z.ai/api/coding/paas/v4";
    wireApi = "chat_completions";
    auth =
      if cfg.zaiCodingPlan.apiKeyFile == null then
        null
      else
        {
          command = "${pkgs.coreutils}/bin/cat";
          args = [ cfg.zaiCodingPlan.apiKeyFile ];
          timeoutMs = 5000;
          refreshIntervalMs = 300000;
        };
  };

  providerPresets = {
    openai = {
      model = "gpt-5.5";
      modelReasoningEffort = "medium";
      modelProviders = { };
      modelCatalog = [ ];
    };

    ai-gateway = {
      model = "openai/gpt-5.5";
      modelReasoningEffort = "medium";
      modelProviders.ai-gateway = aiGatewayProvider;
      modelCatalog = aiGatewayModelCatalog;
    };

    zai-coding-plan = {
      model = "glm-5.2";
      modelReasoningEffort = "medium";
      modelProviders.zai-coding-plan = zaiCodingPlanProvider;
      modelCatalog = zaiCodingPlanModelCatalog;
    };
  };

  selectedProviderPreset =
    if cfg.modelProvider != null && builtins.hasAttr cfg.modelProvider providerPresets then
      providerPresets.${cfg.modelProvider}
    else
      null;

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

  reasoningLevelConfig =
    level: {
      inherit (level) effort description;
    };

  modelCatalogEntry =
    model:
    removeNulls {
      inherit (model) slug;
      display_name = model.displayName;
      description = model.description;
      default_reasoning_level = model.defaultReasoningLevel;
      supported_reasoning_levels = map reasoningLevelConfig model.supportedReasoningLevels;
      shell_type = model.shellType;
      visibility = model.visibility;
      supported_in_api = model.supportedInApi;
      priority = model.priority;
      additional_speed_tiers = model.additionalSpeedTiers;
      supports_reasoning_summaries = model.supportsReasoningSummaries;
      default_reasoning_summary = model.defaultReasoningSummary;
      support_verbosity = model.supportVerbosity;
      default_verbosity = model.defaultVerbosity;
      apply_patch_tool_type = model.applyPatchToolType;
      web_search_tool_type = model.webSearchToolType;
      supports_parallel_tool_calls = model.supportsParallelToolCalls;
      supports_image_detail_original = model.supportsImageDetailOriginal;
      context_window = model.contextWindow;
      max_context_window = model.maxContextWindow;
      effective_context_window_percent = model.effectiveContextWindowPercent;
      input_modalities = model.inputModalities;
      supports_search_tool = model.supportsSearchTool;
      inherit_from_bundled = model.inheritFromBundled;
      base_instructions = model.baseInstructions;
      truncation_policy =
        if model.truncationPolicy == null then
          null
        else
          { inherit (model.truncationPolicy) mode limit; };
      experimental_supported_tools = model.experimentalSupportedTools;
      availability_nux =
        if model.availabilityNux == null then
          null
        else
          { inherit (model.availabilityNux) message; };
      upgrade =
        if model.upgrade == null then
          null
        else
          {
            inherit (model.upgrade) model;
            migration_markdown = model.upgrade.migrationMarkdown;
          };
    };

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
          model_catalog_json =
            if cfg.modelCatalog == [ ] then
              null
            else
              "${generatedModelCatalog}";
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

  modelCatalogEntryType = types.submodule {
    options = {
      slug = mkOption {
        type = types.str;
        description = "Model slug shown to and selected by Codex.";
      };

      displayName = mkOption {
        type = nullable types.str;
        default = null;
        description = "Display name shown in Codex model selection UI.";
      };

      description = mkOption {
        type = nullable types.str;
        default = null;
        description = "Model description shown in Codex model selection UI.";
      };

      defaultReasoningLevel = mkOption {
        type = nullable types.str;
        default = null;
        description = "Default reasoning effort for this model.";
      };

      supportedReasoningLevels = mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              effort = mkOption {
                type = types.str;
                description = "Reasoning effort value.";
              };

              description = mkOption {
                type = types.str;
                description = "Description shown for this reasoning effort.";
              };
            };
          }
        );
        default = [ ];
        description = "Reasoning efforts supported by this model.";
      };

      shellType = mkOption {
        type = nullable types.str;
        default = "shell_command";
        description = "Codex shell tool type used by this model.";
      };

      visibility = mkOption {
        type = nullable types.str;
        default = "list";
        description = "Model visibility in Codex model selection UI.";
      };

      supportedInApi = mkOption {
        type = nullable types.bool;
        default = true;
        description = "Whether this model is supported in the Codex API mode.";
      };

      priority = mkOption {
        type = nullable types.int;
        default = null;
        description = "Sort priority in Codex model selection UI.";
      };

      additionalSpeedTiers = mkOption {
        type = nullable (types.listOf types.str);
        default = null;
        description = "Additional speed tiers supported by this model.";
      };

      supportsReasoningSummaries = mkOption {
        type = nullable types.bool;
        default = true;
        description = "Whether this model supports reasoning summaries.";
      };

      defaultReasoningSummary = mkOption {
        type = nullable types.str;
        default = "none";
        description = "Default reasoning summary setting.";
      };

      supportVerbosity = mkOption {
        type = nullable types.bool;
        default = true;
        description = "Whether this model supports verbosity settings.";
      };

      defaultVerbosity = mkOption {
        type = nullable types.str;
        default = "low";
        description = "Default verbosity setting.";
      };

      applyPatchToolType = mkOption {
        type = nullable types.str;
        default = "freeform";
        description = "Apply-patch tool type used by this model.";
      };

      webSearchToolType = mkOption {
        type = nullable types.str;
        default = "text_and_image";
        description = "Web-search tool type used by this model.";
      };

      supportsParallelToolCalls = mkOption {
        type = nullable types.bool;
        default = true;
        description = "Whether this model supports parallel tool calls.";
      };

      supportsImageDetailOriginal = mkOption {
        type = nullable types.bool;
        default = true;
        description = "Whether this model supports original-detail image inputs.";
      };

      contextWindow = mkOption {
        type = nullable types.int;
        default = null;
        description = "Context window size in tokens.";
      };

      maxContextWindow = mkOption {
        type = nullable types.int;
        default = null;
        description = "Maximum context window size in tokens.";
      };

      effectiveContextWindowPercent = mkOption {
        type = nullable types.int;
        default = null;
        description = "Effective context-window percentage used by Codex.";
      };

      inputModalities = mkOption {
        type = nullable (types.listOf types.str);
        default = [
          "text"
          "image"
        ];
        description = "Input modalities supported by this model.";
      };

      supportsSearchTool = mkOption {
        type = nullable types.bool;
        default = true;
        description = "Whether this model supports the search tool.";
      };

      inheritFromBundled = mkOption {
        type = nullable types.str;
        default = null;
        description = ''
          Bundled Codex model slug to inherit base_instructions, truncation_policy,
          experimental_supported_tools, and model_messages from at build time.
          Resolved by running `codex debug models --bundled` and merging the named
          entry under any explicit overrides on this catalog entry. Requires
          codex.package to be set.
        '';
      };

      baseInstructions = mkOption {
        type = nullable types.str;
        default = null;
        description = ''
          Override base_instructions for this model. Takes precedence over the
          value pulled in via inheritFromBundled.
        '';
      };

      truncationPolicy = mkOption {
        type = nullable (
          types.submodule {
            options = {
              mode = mkOption {
                type = types.enum [ "tokens" "bytes" ];
                description = "Truncation mode.";
              };

              limit = mkOption {
                type = types.int;
                description = "Truncation limit (tokens or bytes, per mode).";
              };
            };
          }
        );
        default = null;
        description = ''
          Override truncation_policy for this model. Takes precedence over the
          value pulled in via inheritFromBundled.
        '';
      };

      experimentalSupportedTools = mkOption {
        type = nullable (types.listOf types.str);
        default = null;
        description = ''
          Override experimental_supported_tools for this model. Takes precedence
          over the value pulled in via inheritFromBundled.
        '';
      };

      availabilityNux = mkOption {
        type = nullable (
          types.submodule {
            options = {
              message = mkOption {
                type = types.str;
                description = "Notice shown when this model first becomes available.";
              };
            };
          }
        );
        default = null;
        description = "Optional availability_nux notice for this model.";
      };

      upgrade = mkOption {
        type = nullable (
          types.submodule {
            options = {
              model = mkOption {
                type = types.str;
                description = "Slug of the model recommended as an upgrade.";
              };

              migrationMarkdown = mkOption {
                type = types.str;
                description = "Markdown shown when prompting the user to upgrade.";
              };
            };
          }
        );
        default = null;
        description = "Optional upgrade prompt for this model.";
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

    aiGateway = {
      apiKeyFile = mkOption {
        type = nullable types.str;
        default = null;
        description = ''
          Path to a file containing the Vercel AI Gateway API key. Used when
          codex.modelProvider is set to ai-gateway.
        '';
      };
    };

    zaiCodingPlan = {
      apiKeyFile = mkOption {
        type = nullable types.str;
        default = null;
        description = ''
          Path to a file containing the z.ai GLM Coding Plan API key. Used when
          codex.modelProvider is set to zai-coding-plan.
        '';
      };
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

    modelCatalog = mkOption {
      type = types.listOf modelCatalogEntryType;
      default = [ ];
      description = "Typed Codex model catalog entries serialized to model_catalog_json.";
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

  config = mkIf cfg.enable (lib.mkMerge [
    (mkIf (selectedProviderPreset != null) {
      codex = {
        model = lib.mkDefault selectedProviderPreset.model;
        modelReasoningEffort = lib.mkDefault selectedProviderPreset.modelReasoningEffort;
        modelProviders = lib.mkDefault selectedProviderPreset.modelProviders;
        modelCatalog = lib.mkDefault selectedProviderPreset.modelCatalog;
      };
    })
    {
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
        {
          assertion = !modelCatalogUsesBundled || cfg.package != null;
          message = "codex.modelCatalog entries that set inheritFromBundled require codex.package to be set so the bundled catalog can be read at build time.";
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
    }
  ]);
}
