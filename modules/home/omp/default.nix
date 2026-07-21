{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.omp;
  json = pkgs.formats.json { };

  nullable = type: types.nullOr type;
  stringList = types.listOf types.str;
  stringMap = types.attrsOf types.str;

  nullableOption =
    type: description:
    mkOption {
      type = nullable type;
      default = null;
      inherit description;
    };

  enumOption = values: description: nullableOption (types.enum values) description;

  removeNulls =
    value:
    if builtins.isAttrs value then
      lib.filterAttrs (_: item: item != null && !(builtins.isAttrs item && item == { }))
        (
          lib.mapAttrs (_: removeNulls) value
        )
    else if builtins.isList value then
      map removeNulls value
    else
      value;

  mergeAll = lib.foldl' lib.recursiveUpdate { };

  apiType = types.enum [
    "openai-completions"
    "openai-responses"
    "openai-codex-responses"
    "azure-openai-responses"
    "anthropic-messages"
    "google-generative-ai"
    "google-vertex"
  ];

  effortType = types.enum [
    "minimal"
    "low"
    "medium"
    "high"
    "xhigh"
  ];

  reasoningEffortMapType = types.submodule {
    options = lib.genAttrs [
      "minimal"
      "low"
      "medium"
      "high"
      "xhigh"
    ]
      (name: nullableOption types.str "Provider value for the ${name} reasoning effort.");
  };

  thinkingType = types.submodule {
    options = {
      mode = mkOption {
        type = types.enum [
          "effort"
          "budget"
          "google-level"
          "anthropic-adaptive"
          "anthropic-budget-effort"
        ];
        description = "Model thinking control mode.";
      };
      efforts = mkOption {
        type = types.nonEmptyListOf effortType;
        description = "Supported reasoning efforts.";
      };
      defaultLevel = nullableOption effortType "Default reasoning effort.";
      effortMap = nullableOption reasoningEffortMapType "Provider-specific reasoning effort values.";
      supportsDisplay = nullableOption types.bool "Whether OMP may display thinking output.";
    };
  };

  routingType = types.submodule {
    options = {
      only = nullableOption stringList "Allowed upstream providers.";
      order = nullableOption stringList "Preferred upstream provider order.";
    };
  };

  compatType = types.submodule {
    options = {
      supportsStore = nullableOption types.bool "Whether the endpoint supports stored responses.";
      supportsDeveloperRole = nullableOption types.bool "Whether the endpoint supports developer messages.";
      supportsMultipleSystemMessages = nullableOption types.bool "Whether the endpoint supports multiple system messages.";
      supportsReasoningEffort = nullableOption types.bool "Whether the endpoint supports reasoning effort.";
      reasoningEffortMap = nullableOption reasoningEffortMapType "Provider-specific reasoning effort values.";
      maxTokensField = enumOption [
        "max_completion_tokens"
        "max_tokens"
      ] "Request field used for maximum output tokens.";
      supportsUsageInStreaming = nullableOption types.bool "Whether streamed responses include usage.";
      requiresToolResultName = nullableOption types.bool "Whether tool results require a name.";
      requiresMistralToolIds = nullableOption types.bool "Whether Mistral-style tool IDs are required.";
      requiresAssistantAfterToolResult = nullableOption types.bool "Whether an assistant message must follow tool results.";
      requiresThinkingAsText = nullableOption types.bool "Whether thinking must be replayed as text.";
      reasoningContentField = enumOption [
        "reasoning_content"
        "reasoning"
        "reasoning_text"
      ] "Response field containing reasoning text.";
      requiresReasoningContentForToolCalls = nullableOption types.bool "Whether tool calls require reasoning content.";
      allowsSyntheticReasoningContentForToolCalls = nullableOption types.bool "Whether OMP may synthesize reasoning content for tool calls.";
      requiresAssistantContentForToolCalls = nullableOption types.bool "Whether tool calls require assistant content.";
      supportsToolChoice = nullableOption types.bool "Whether the endpoint supports tool choice.";
      disableReasoningOnForcedToolChoice = nullableOption types.bool "Whether forced tool choice disables reasoning.";
      disableReasoningOnToolChoice = nullableOption types.bool "Whether any tool choice disables reasoning.";
      thinkingFormat = enumOption [
        "openai"
        "openrouter"
        "zai"
        "qwen"
        "qwen-chat-template"
      ] "Thinking wire format.";
      openRouterRouting = nullableOption routingType "OpenRouter routing controls.";
      vercelGatewayRouting = nullableOption routingType "Vercel AI Gateway routing controls.";
      extraBody = nullableOption json.type "Additional request body fields.";
      cacheControlFormat = enumOption [ "anthropic" ] "Prompt cache-control format.";
      supportsStrictMode = nullableOption types.bool "Whether strict tools are supported.";
      toolStrictMode = enumOption [
        "all_strict"
        "none"
      ] "Strict tool policy.";
      streamIdleTimeoutMs = nullableOption types.int "Streaming idle timeout in milliseconds.";
      supportsLongPromptCacheRetention = nullableOption types.bool "Whether long prompt cache retention is supported.";
      supportsReasoningParams = nullableOption types.bool "Whether reasoning parameters are supported.";
      alwaysSendMaxTokens = nullableOption types.bool "Whether to always send the maximum token field.";
      strictResponsesPairing = nullableOption types.bool "Whether Responses API item pairing is strict.";
      requiresToolResultId = nullableOption types.bool "Whether Anthropic tool results require an ID.";
      replayUnsignedThinking = nullableOption types.bool "Whether unsigned Anthropic thinking may be replayed.";
      whenThinking = nullableOption json.type "Compatibility overrides applied while thinking is enabled.";
    };
  };

  modelCostType = types.submodule {
    options = {
      input = mkOption {
        type = types.number;
        description = "Input token cost.";
      };
      output = mkOption {
        type = types.number;
        description = "Output token cost.";
      };
      cacheRead = mkOption {
        type = types.number;
        description = "Cache-read token cost.";
      };
      cacheWrite = mkOption {
        type = types.number;
        description = "Cache-write token cost.";
      };
    };
  };

  overrideCostType = types.submodule {
    options = {
      input = nullableOption types.number "Input token cost.";
      output = nullableOption types.number "Output token cost.";
      cacheRead = nullableOption types.number "Cache-read token cost.";
      cacheWrite = nullableOption types.number "Cache-write token cost.";
    };
  };

  modelOptions = {
    id = mkOption {
      type = types.str;
      description = "Provider model ID.";
    };
    name = nullableOption types.str "Display name.";
    api = nullableOption apiType "Wire API used by this model.";
    baseUrl = nullableOption types.str "Model-specific API base URL.";
    reasoning = nullableOption types.bool "Whether the model supports reasoning.";
    thinking = nullableOption thinkingType "Thinking controls.";
    input = nullableOption
      (types.listOf (
        types.enum [
          "text"
          "image"
        ]
      )) "Supported input modalities.";
    cost = nullableOption modelCostType "Token costs.";
    premiumMultiplier = nullableOption types.number "Premium usage multiplier.";
    contextWindow = nullableOption types.ints.positive "Context window size.";
    maxTokens = nullableOption types.ints.positive "Maximum output tokens.";
    omitMaxOutputTokens = nullableOption types.bool "Whether maximum output tokens should be omitted.";
    headers = nullableOption stringMap "Model-specific HTTP headers.";
    compat = nullableOption compatType "Endpoint compatibility controls.";
    contextPromotionTarget = nullableOption types.str "Model selector used for context promotion.";
  };

  modelType = types.submodule { options = modelOptions; };

  modelOverrideType = types.submodule {
    options =
      builtins.removeAttrs modelOptions [
        "id"
        "api"
        "baseUrl"
        "cost"
      ]
      // {
        cost = nullableOption overrideCostType "Partial token cost overrides.";
      };
  };

  providerType = types.submodule {
    options = {
      baseUrl = nullableOption types.str "Provider API base URL.";
      apiKey = nullableOption types.str "API key or a command-prefixed secret expression.";
      api = nullableOption apiType "Provider wire API.";
      headers = nullableOption stringMap "Provider HTTP headers.";
      compat = nullableOption compatType "Provider compatibility controls.";
      authHeader = nullableOption types.bool "Whether to send the API key in an authorization header.";
      auth = enumOption [
        "apiKey"
        "none"
        "oauth"
      ] "Provider authentication mode.";
      discovery = nullableOption
        (types.submodule {
          options.type = mkOption {
            type = types.enum [
              "ollama"
              "llama.cpp"
              "lm-studio"
              "openai-models-list"
              "proxy"
            ];
            description = "Runtime model discovery protocol.";
          };
        }) "Runtime model discovery configuration.";
      models = nullableOption (types.listOf modelType) "Provider model catalog.";
      modelOverrides = nullableOption (types.attrsOf modelOverrideType) "Overrides for bundled or discovered models.";
      disableStrictTools = nullableOption types.bool "Disable strict tool schemas for this provider.";
      transport = enumOption [ "pi-native" ] "Provider streaming transport.";
    };
  };

  managedFileType = types.submodule {
    options = {
      text = nullableOption types.lines "Inline file contents.";
      source = nullableOption types.path "Source file or directory.";
      executable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether the managed file is executable.";
      };
      recursive = mkOption {
        type = types.bool;
        default = false;
        description = "Whether a source directory is linked recursively.";
      };
    };
  };

  promptFileType = nullable managedFileType;
  pluginType = types.submodule {
    options = {
      package = mkOption {
        type = nullable types.package;
        default = null;
        description = ''
          Store package for this OMP plugin. When set, the module links the
          package into ~/.omp/plugins/node_modules and records matching plugin
          runtime state for OMP discovery.
        '';
      };
      name = nullableOption types.str "Package name used under ~/.omp/plugins/node_modules. Defaults to the attr name.";
      version = nullableOption types.str "Plugin version recorded in omp-plugins.lock.json. Defaults to package.version when available.";
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether OMP should treat this plugin as enabled.";
      };
      features = mkOption {
        type = nullable stringList;
        default = null;
        description = "Enabled OMP plugin features. Null means OMP default features.";
      };
      settings = mkOption {
        type = json.type;
        default = { };
        description = "Plugin settings recorded in omp-plugins.lock.json.";
      };
    };
  };


  typedSettings = removeNulls {
    setupVersion = cfg.setupVersion;
    modelRoles = {
      default = cfg.defaultModel;
      smol = cfg.smolModel;
      slow = cfg.slowModel;
      plan = cfg.planModel;
      vision = cfg.visionModel;
      designer = cfg.designerModel;
      commit = cfg.commitModel;
      task = cfg.taskModel;
    };
    enabledModels = cfg.enabledModels;

    theme = {
      dark = cfg.appearance.themeDark;
      light = cfg.appearance.themeLight;
    };
    symbolPreset = cfg.appearance.symbolPreset;
    colorBlindMode = cfg.appearance.colorBlindMode;
    statusLine = {
      preset = cfg.appearance.statusLinePreset;
      separator = cfg.appearance.statusLineSeparator;
      sessionAccent = cfg.appearance.statusLineSessionAccent;
      transparent = cfg.appearance.statusLineTransparent;
      showHookStatus = cfg.appearance.statusLineShowHookStatus;
      leftSegments = cfg.appearance.statusLineLeftSegments;
      rightSegments = cfg.appearance.statusLineRightSegments;
      segmentOptions = cfg.appearance.statusLineSegmentOptions;
    };
    display = {
      tabWidth = cfg.appearance.tabWidth;
      shimmer = cfg.appearance.shimmer;
      smoothStreaming = cfg.appearance.smoothStreaming;
      showTokenUsage = cfg.appearance.showTokenUsage;
    };
    terminal.showImages = cfg.appearance.showImages;
    images = {
      autoResize = cfg.appearance.imageAutoResize;
      blockImages = cfg.appearance.blockImages;
    };
    tui = {
      maxInlineImageColumns = cfg.appearance.maxInlineImageColumns;
      maxInlineImageRows = cfg.appearance.maxInlineImageRows;
      maxInlineImages = cfg.appearance.maxInlineImages;
      textSizing = cfg.appearance.textSizing;
      hyperlinks = cfg.appearance.hyperlinks;
    };
    showHardwareCursor = cfg.appearance.showHardwareCursor;

    modelTags = cfg.model.tags;
    modelProviderOrder = cfg.model.providerOrder;
    cycleOrder = cfg.model.cycleOrder;
    defaultThinkingLevel = cfg.model.defaultThinkingLevel;
    hideThinkingBlock = cfg.model.hideThinkingBlock;
    repeatToolDescriptions = cfg.model.repeatToolDescriptions;
    includeModelInPrompt = cfg.model.includeModelInPrompt;
    personality = cfg.model.personality;
    temperature = cfg.model.temperature;
    topP = cfg.model.topP;
    topK = cfg.model.topK;
    minP = cfg.model.minP;
    presencePenalty = cfg.model.presencePenalty;
    repetitionPenalty = cfg.model.repetitionPenalty;
    serviceTier = cfg.model.serviceTier;
    retry = {
      enabled = cfg.model.retryEnabled;
      maxRetries = cfg.model.maxRetries;
      baseDelayMs = cfg.model.retryBaseDelayMs;
      maxDelayMs = cfg.model.retryMaxDelayMs;
      modelFallback = cfg.model.modelFallback;
      fallbackChains = cfg.model.fallbackChains;
      fallbackRevertPolicy = cfg.model.fallbackRevertPolicy;
    };

    autoResume = cfg.interaction.autoResume;
    steeringMode = cfg.interaction.steeringMode;
    followUpMode = cfg.interaction.followUpMode;
    interruptMode = cfg.interaction.interruptMode;
    loop.mode = cfg.interaction.loopMode;
    doubleEscapeAction = cfg.interaction.doubleEscapeAction;
    treeFilterMode = cfg.interaction.treeFilterMode;
    autocompleteMaxVisible = cfg.interaction.autocompleteMaxVisible;
    emojiAutocomplete = cfg.interaction.emojiAutocomplete;
    startup = {
      quiet = cfg.interaction.startupQuiet;
      setupWizard = cfg.interaction.setupWizard;
      checkUpdate = cfg.interaction.checkUpdate;
    };
    completion.notify = cfg.interaction.completionNotify;
    ask = {
      timeout = cfg.interaction.approvalTimeout;
      notify = cfg.interaction.approvalNotify;
    };
    collapseChangelog = cfg.interaction.collapseChangelog;

    contextPromotion.enabled = cfg.context.promotionEnabled;
    compaction = {
      enabled = cfg.context.compactionEnabled;
      strategy = cfg.context.compactionStrategy;
      thresholdPercent = cfg.context.compactionThresholdPercent;
      thresholdTokens = cfg.context.compactionThresholdTokens;
      reserveTokens = cfg.context.compactionReserveTokens;
      keepRecentTokens = cfg.context.compactionKeepRecentTokens;
      autoContinue = cfg.context.compactionAutoContinue;
      supersedeReads = cfg.context.compactionSupersedeReads;
      dropUseless = cfg.context.compactionDropUseless;
    };
    branchSummary = {
      enabled = cfg.context.branchSummaryEnabled;
      reserveTokens = cfg.context.branchSummaryReserveTokens;
    };
    ttsr = {
      enabled = cfg.context.ttsrEnabled;
      contextMode = cfg.context.ttsrContextMode;
      interruptMode = cfg.context.ttsrInterruptMode;
      repeatMode = cfg.context.ttsrRepeatMode;
      repeatGap = cfg.context.ttsrRepeatGap;
      builtinRules = cfg.context.ttsrBuiltinRules;
      disabledRules = cfg.context.ttsrDisabledRules;
    };

    memories = {
      enabled = cfg.memory.commonEnabled;
      maxRolloutsPerStartup = cfg.memory.maxRolloutsPerStartup;
      maxRolloutAgeDays = cfg.memory.maxRolloutAgeDays;
      minRolloutIdleHours = cfg.memory.minRolloutIdleHours;
      threadScanLimit = cfg.memory.threadScanLimit;
      summaryInjectionTokenLimit = cfg.memory.summaryInjectionTokenLimit;
    };
    memory.backend = cfg.memory.backend;

    edit = {
      mode = cfg.files.editMode;
      fuzzyMatch = cfg.files.fuzzyMatch;
      fuzzyThreshold = cfg.files.fuzzyThreshold;
      streamingAbort = cfg.files.streamingAbort;
      blockAutoGenerated = cfg.files.blockAutoGenerated;
      enforceSeenLines = cfg.files.enforceSeenLines;
    };
    readLineNumbers = cfg.files.readLineNumbers;
    readHashLines = cfg.files.readHashLines;
    read = {
      defaultLimit = cfg.files.readDefaultLimit;
      summarize = {
        enabled = cfg.files.summarizeEnabled;
        prose = cfg.files.summarizeProse;
        minBodyLines = cfg.files.summarizeMinBodyLines;
        minCommentLines = cfg.files.summarizeMinCommentLines;
        minTotalLines = cfg.files.summarizeMinTotalLines;
        unfoldUntil = cfg.files.summarizeUnfoldUntil;
        unfoldLimit = cfg.files.summarizeUnfoldLimit;
      };
      toolResultPreview = cfg.files.toolResultPreview;
    };
    lsp = {
      enabled = cfg.files.lspEnabled;
      lazy = cfg.files.lspLazy;
      formatOnWrite = cfg.files.lspFormatOnWrite;
      diagnosticsOnWrite = cfg.files.lspDiagnosticsOnWrite;
      diagnosticsOnEdit = cfg.files.lspDiagnosticsOnEdit;
      diagnosticsDeduplicate = cfg.files.lspDiagnosticsDeduplicate;
    };

    shellPath = cfg.shell.path;
    bash = {
      enabled = cfg.shell.bashEnabled;
      autoBackground.enabled = cfg.shell.autoBackground;
      stripTrailingHeadTail = cfg.shell.stripTrailingHeadTail;
    };
    bashInterceptor = {
      enabled = cfg.shell.interceptorEnabled;
      patterns = cfg.shell.interceptorPatterns;
    };
    eval = {
      py = cfg.shell.evalPython;
      js = cfg.shell.evalJavaScript;
    };
    python = {
      kernelMode = cfg.shell.pythonKernelMode;
      interpreter = cfg.shell.pythonInterpreter;
    };

    tools = {
      approval = cfg.tools.approval;
      approvalMode = cfg.tools.approvalMode;
      artifactSpillThreshold = cfg.tools.artifactSpillThreshold;
      artifactHeadBytes = cfg.tools.artifactHeadBytes;
      artifactTailBytes = cfg.tools.artifactTailBytes;
      artifactTailLines = cfg.tools.artifactTailLines;
      outputMaxColumns = cfg.tools.outputMaxColumns;
      maxTimeout = cfg.tools.maxTimeout;
      xdev = cfg.tools.xdevEnabled;
      intentTracing = cfg.tools.intentTracing;
    };
    todo.enabled = cfg.tools.todoEnabled;
    find.enabled = cfg.tools.findEnabled;
    search = {
      enabled = cfg.tools.searchEnabled;
      contextBefore = cfg.tools.searchContextBefore;
      contextAfter = cfg.tools.searchContextAfter;
    };
    astGrep.enabled = cfg.tools.astGrepEnabled;
    astEdit.enabled = cfg.tools.astEditEnabled;
    fetch.enabled = cfg.tools.fetchEnabled;
    web_search.enabled = cfg.tools.webSearchEnabled;
    browser = {
      enabled = cfg.tools.browserEnabled;
      headless = cfg.tools.browserHeadless;
      screenshotDir = cfg.tools.browserScreenshotDir;
    };
    github.enabled = cfg.tools.githubEnabled;
    async = {
      enabled = cfg.tools.asyncEnabled;
      maxJobs = cfg.tools.asyncMaxJobs;
    };

    plan.enabled = cfg.tasks.planEnabled;
    goal = {
      enabled = cfg.tasks.goalEnabled;
      statusInFooter = cfg.tasks.goalStatusInFooter;
      continuationModes = cfg.tasks.goalContinuationModes;
    };
    task = {
      isolation = {
        mode = cfg.tasks.isolationMode;
        merge = cfg.tasks.isolationMerge;
        commits = cfg.tasks.isolationCommits;
      };
      eager = cfg.tasks.eager;
      batch = cfg.tasks.batch;
      maxConcurrency = cfg.tasks.maxConcurrency;
      enableLsp = cfg.tasks.enableLsp;
      maxRecursionDepth = cfg.tasks.maxRecursionDepth;
      maxRuntimeMs = cfg.tasks.maxRuntimeMs;
      disabledAgents = cfg.tasks.disabledAgents;
      agentModelOverrides = cfg.tasks.agentModelOverrides;
      showResolvedModelBadge = cfg.tasks.showResolvedModelBadge;
    };
    skills = {
      enabled = cfg.tasks.skillsEnabled;
      enableSkillCommands = cfg.tasks.enableSkillCommands;
      customDirectories = cfg.tasks.skillDirectories;
      ignoredSkills = cfg.tasks.ignoredSkills;
      includeSkills = cfg.tasks.includeSkills;
    };

    disabledProviders = cfg.providers.disabled;
    providers = {
      webSearch = cfg.providers.webSearch;
      image = cfg.providers.image;
      tinyModel = cfg.providers.tinyModel;
      tinyModelDevice = cfg.providers.tinyModelDevice;
      tinyModelDtype = cfg.providers.tinyModelDtype;
      memoryModel = cfg.providers.memoryModel;
      autoThinkingModel = cfg.providers.autoThinkingModel;
      kimiApiFormat = cfg.providers.kimiApiFormat;
      openaiWebsockets = cfg.providers.openaiWebsockets;
      openrouterVariant = cfg.providers.openrouterVariant;
      fetch = cfg.providers.fetch;
    };
    provider.appendOnlyContext = cfg.providers.appendOnlyContext;
    secrets.enabled = cfg.providers.secretsEnabled;
    share.redactSecrets = cfg.providers.redactSecrets;
  };

  configSettings = mergeAll [
    typedSettings
    cfg.settings
    cfg.extraConfig
  ];

  providersConfig = lib.mapAttrs (_: provider: removeNulls provider) cfg.modelProviders;

  modelsConfig = mergeAll [
    (removeNulls {
      providers = providersConfig;
      equivalence = {
        overrides = cfg.modelEquivalence.overrides;
        exclude = cfg.modelEquivalence.exclude;
      };
    })
    cfg.extraModels
  ];

  configContent = builtins.toJSON configSettings;
  modelsContent = builtins.toJSON modelsConfig;

  promptFiles = lib.filterAttrs (_: value: value != null) {
    "SYSTEM.md" = cfg.prompts.system;
    "APPEND_SYSTEM.md" = cfg.prompts.appendSystem;
    "TITLE_SYSTEM.md" = cfg.prompts.titleSystem;
    "AGENTS.md" = cfg.prompts.agents;
  };

  generatedThemeFiles = lib.mapAttrs'
    (
      name: value:
        lib.nameValuePair ".omp/agent/themes/${name}.json" {
          text = builtins.toJSON value;
        }
    )
    cfg.themes;

  fileConfig =
    file:
    removeNulls {
      inherit (file)
        text
        source
        executable
        recursive
        ;
    };

  generatedPromptFiles = lib.mapAttrs'
    (
      name: value: lib.nameValuePair ".omp/agent/${name}" (fileConfig value)
    )
    promptFiles;

  generatedAgentFiles = lib.mapAttrs'
    (
      name: value: lib.nameValuePair ".omp/agent/${name}" (fileConfig value)
    )
    cfg.agentFiles;
  pluginName = attrName: plugin: if plugin.name != null then plugin.name else attrName;

  configuredPlugins = lib.mapAttrsToList
    (attrName: plugin: {
      name = pluginName attrName plugin;
      inherit attrName plugin;
    })
    cfg.plugins;

  packagedPlugins = lib.filter (entry: entry.plugin.package != null) configuredPlugins;

  pluginsByName = builtins.listToAttrs (
    map (entry: lib.nameValuePair entry.name entry.plugin) packagedPlugins
  );

  pluginVersion = plugin:
    if plugin.version != null then
      plugin.version
    else
      plugin.package.version or "0.0.0";

  pluginPackageJson = {
    name = "omp-plugins";
    private = true;
    dependencies = lib.mapAttrs (_: plugin: "file:${builtins.unsafeDiscardStringContext "${plugin.package}"}") pluginsByName;
  };

  pluginLockJson = {
    plugins = lib.mapAttrs
      (_: plugin: {
        version = pluginVersion plugin;
        enabledFeatures = plugin.features;
        enabled = plugin.enable;
      })
      pluginsByName;
    settings = lib.mapAttrs (_: plugin: plugin.settings) pluginsByName;
  };

  generatedPluginFiles = lib.optionalAttrs (pluginsByName != { }) ({
    ".omp/plugins/package.json".text = builtins.toJSON pluginPackageJson;
    ".omp/plugins/omp-plugins.lock.json".text = builtins.toJSON pluginLockJson;
  } // lib.mapAttrs'
    (name: plugin: lib.nameValuePair ".omp/plugins/node_modules/${name}" {
      source = plugin.package;
    })
    pluginsByName);

  effectivePluginNames = map (entry: entry.name) configuredPlugins;
  duplicatePluginNames = lib.filter
    (
      name: builtins.length (lib.filter (candidate: candidate == name) effectivePluginNames) > 1
    )
    (lib.unique effectivePluginNames);
  unsafePluginNames = lib.filter
    (
      name:
      name == "" || lib.hasPrefix "/" name || lib.any (part: part == "..") (lib.splitString "/" name)
    )
    effectivePluginNames;


  agentFileNames = builtins.attrNames cfg.agentFiles;
  unsafeAgentFileNames = lib.filter
    (
      name:
      name == "" || lib.hasPrefix "/" name || lib.any (part: part == "..") (lib.splitString "/" name)
    )
    agentFileNames;

  reservedPaths = [
    "config.yml"
    "models.yml"
    "keybindings.yml"
    "SYSTEM.md"
    "APPEND_SYSTEM.md"
    "TITLE_SYSTEM.md"
    "AGENTS.md"
  ]
  ++ map (themeName: "themes/${themeName}.json") (builtins.attrNames cfg.themes);

  pathsCollide =
    left: right: left == right || lib.hasPrefix "${left}/" right || lib.hasPrefix "${right}/" left;

  collidingAgentFileNames = lib.filter
    (
      name: lib.any (reservedPath: pathsCollide name reservedPath) reservedPaths
    )
    agentFileNames;

  invalidManagedFiles = lib.filter
    (
      name:
      let
        file = cfg.agentFiles.${name};
      in
      (file.text == null) == (file.source == null)
    )
    agentFileNames;

  invalidPromptFiles = lib.filter
    (
      name:
      let
        file = promptFiles.${name};
      in
      (file.text == null) == (file.source == null)
    )
    (builtins.attrNames promptFiles);

  providerValidationErrors = lib.concatLists (
    lib.mapAttrsToList
      (
        name: provider:
          let
            value = removeNulls provider;
            models = value.models or [ ];
            hasModels = models != [ ];
            hasApiKey = value ? apiKey;
            auth = value.auth or "apiKey";
            hasOverride = lib.any (field: value ? ${field}) [
              "baseUrl"
              "apiKey"
              "headers"
              "compat"
              "disableStrictTools"
              "modelOverrides"
              "discovery"
            ];
            modelsMissingApi = lib.any (model: !(model ? api) && !(value ? api)) models;
          in
          lib.optional
            (
              hasModels && !(value ? baseUrl)
            ) "omp.modelProviders.${name}.baseUrl is required when models are configured."
          ++ lib.optional
            (
              hasModels && !hasApiKey && auth != "none"
            ) "omp.modelProviders.${name}.apiKey is required unless auth = \"none\"."
          ++ lib.optional
            (
              hasModels && modelsMissingApi
            ) "omp.modelProviders.${name} must set api or set api on every model."
          ++ lib.optional
            (
              !hasModels && !hasOverride
            ) "omp.modelProviders.${name} must configure models or at least one provider override."
          ++ lib.optional
            (
              value ? discovery && value.discovery.type != "proxy" && !(value ? api)
            ) "omp.modelProviders.${name}.api is required for non-proxy discovery."
      )
      cfg.modelProviders
  );

  settingGroup =
    options:
    types.submodule {
      inherit options;
    };
in
{
  options.omp = {
    enable = mkEnableOption "oh-my-pi";

    package = mkOption {
      type = nullable types.package;
      default = null;
      description = "Oh My Pi package to install. Set to null to manage only configuration.";
    };

    setupVersion = nullableOption types.int "Completed OMP setup wizard schema version.";

    defaultModel = nullableOption types.str "Default OMP model selector.";
    planModel = nullableOption types.str "OMP model selector used for planning.";
    smolModel = nullableOption types.str "OMP model selector used for small tasks.";
    commitModel = nullableOption types.str "OMP model selector used for commit generation.";
    slowModel = nullableOption types.str "OMP model selector used for deep reasoning.";
    visionModel = nullableOption types.str "OMP model selector used for image-capable fallback.";
    designerModel = nullableOption types.str "OMP model selector used for the designer subagent.";
    taskModel = nullableOption types.str "OMP model selector used for subagent work.";
    enabledModels = nullableOption stringList "OMP enabled model patterns.";

    appearance = mkOption {
      type = settingGroup {
        themeDark = nullableOption types.str "Dark terminal theme.";
        themeLight = nullableOption types.str "Light terminal theme.";
        symbolPreset = enumOption [
          "unicode"
          "nerd"
          "ascii"
        ] "Symbol preset.";
        colorBlindMode = nullableOption types.bool "Enable color-blind-friendly rendering.";
        statusLinePreset = nullableOption types.str "Status line preset.";
        statusLineSeparator = nullableOption types.str "Status line separator.";
        statusLineSessionAccent = nullableOption types.str "Session accent color.";
        statusLineTransparent = nullableOption types.bool "Use a transparent status line.";
        statusLineShowHookStatus = nullableOption types.bool "Show hook status.";
        statusLineLeftSegments = nullableOption stringList "Left status line segments.";
        statusLineRightSegments = nullableOption stringList "Right status line segments.";
        statusLineSegmentOptions = nullableOption json.type "Per-segment status line options.";
        tabWidth = nullableOption types.int "Display tab width.";
        shimmer = nullableOption types.bool "Enable shimmer effects.";
        smoothStreaming = nullableOption types.bool "Enable smooth streamed rendering.";
        showTokenUsage = nullableOption types.bool "Show token usage.";
        showImages = nullableOption types.bool "Render terminal images.";
        imageAutoResize = nullableOption types.bool "Resize images automatically.";
        blockImages = nullableOption types.bool "Block image input.";
        maxInlineImageColumns = nullableOption types.int "Maximum inline image width.";
        maxInlineImageRows = nullableOption types.int "Maximum inline image height.";
        maxInlineImages = nullableOption types.int "Maximum number of inline images.";
        textSizing = nullableOption types.bool "Enable terminal text sizing.";
        hyperlinks = nullableOption types.bool "Enable terminal hyperlinks.";
        showHardwareCursor = nullableOption types.bool "Show the hardware cursor.";
      };
      default = { };
      description = "Appearance, status line, terminal, and image settings.";
    };

    model = mkOption {
      type = settingGroup {
        tags = nullableOption json.type "Model tag definitions.";
        providerOrder = nullableOption stringList "Canonical provider precedence.";
        cycleOrder = nullableOption stringList "Model cycling order.";
        defaultThinkingLevel = nullableOption
          (types.oneOf [
            effortType
            (types.enum [ "auto" ])
          ]) "Default thinking level.";
        hideThinkingBlock = nullableOption types.bool "Hide model thinking blocks.";
        repeatToolDescriptions = nullableOption types.bool "Repeat tool descriptions in prompts.";
        includeModelInPrompt = nullableOption types.bool "Include the model identity in prompts.";
        personality = nullableOption types.str "Prompt personality.";
        temperature = nullableOption types.number "Sampling temperature.";
        topP = nullableOption types.number "Top-p sampling value.";
        topK = nullableOption types.number "Top-k sampling value.";
        minP = nullableOption types.number "Minimum-p sampling value.";
        presencePenalty = nullableOption types.number "Presence penalty.";
        repetitionPenalty = nullableOption types.number "Repetition penalty.";
        serviceTier = nullableOption types.str "Provider service tier.";
        retryEnabled = nullableOption types.bool "Enable provider retries.";
        maxRetries = nullableOption types.int "Maximum retry count.";
        retryBaseDelayMs = nullableOption types.int "Initial retry delay.";
        retryMaxDelayMs = nullableOption types.int "Maximum retry delay.";
        modelFallback = nullableOption types.bool "Enable model fallback.";
        fallbackChains = nullableOption (types.attrsOf stringList) "Model fallback chains.";
        fallbackRevertPolicy = enumOption [
          "never"
          "session"
          "turn"
        ] "Fallback reversion policy.";
      };
      default = { };
      description = "Model selection, thinking, sampling, and retry settings.";
    };

    interaction = mkOption {
      type = settingGroup {
        autoResume = nullableOption types.bool "Resume the most recent session automatically.";
        steeringMode = nullableOption types.str "Steering input queue mode.";
        followUpMode = nullableOption types.str "Follow-up input queue mode.";
        interruptMode = nullableOption types.str "Interrupt handling mode.";
        loopMode = nullableOption types.str "Agent loop mode.";
        doubleEscapeAction = nullableOption types.str "Double-Escape action.";
        treeFilterMode = nullableOption types.str "Session tree filter mode.";
        autocompleteMaxVisible = nullableOption types.int "Maximum visible autocomplete entries.";
        emojiAutocomplete = nullableOption types.bool "Enable emoji autocomplete.";
        startupQuiet = nullableOption types.bool "Suppress startup output.";
        setupWizard = nullableOption types.bool "Run the setup wizard.";
        checkUpdate = nullableOption types.bool "Check for updates at startup.";
        completionNotify = nullableOption types.bool "Notify when generation completes.";
        approvalTimeout = nullableOption types.int "Approval timeout in seconds.";
        approvalNotify = nullableOption types.bool "Notify when approval is required.";
        collapseChangelog = nullableOption types.bool "Collapse startup changelog output.";
      };
      default = { };
      description = "Input, approvals, notifications, and startup settings.";
    };

    context = mkOption {
      type = settingGroup {
        promotionEnabled = nullableOption types.bool "Enable context-window model promotion.";
        compactionEnabled = nullableOption types.bool "Enable context compaction.";
        compactionStrategy = nullableOption types.str "Compaction strategy.";
        compactionThresholdPercent = nullableOption types.number "Compaction threshold percentage.";
        compactionThresholdTokens = nullableOption types.int "Compaction threshold token count.";
        compactionReserveTokens = nullableOption types.int "Tokens reserved during compaction.";
        compactionKeepRecentTokens = nullableOption types.int "Recent tokens retained during compaction.";
        compactionAutoContinue = nullableOption types.bool "Continue automatically after compaction.";
        compactionSupersedeReads = nullableOption types.bool "Supersede redundant read results.";
        compactionDropUseless = nullableOption types.bool "Drop low-value context during compaction.";
        branchSummaryEnabled = nullableOption types.bool "Enable branch summaries.";
        branchSummaryReserveTokens = nullableOption types.int "Tokens reserved for branch summaries.";
        ttsrEnabled = nullableOption types.bool "Enable Time Traveling Stream Rules.";
        ttsrContextMode = nullableOption types.str "TTSR context injection mode.";
        ttsrInterruptMode = nullableOption types.str "TTSR interrupt mode.";
        ttsrRepeatMode = nullableOption types.str "TTSR repeat mode.";
        ttsrRepeatGap = nullableOption types.int "TTSR repeat gap.";
        ttsrBuiltinRules = nullableOption stringList "Enabled built-in TTSR rules.";
        ttsrDisabledRules = nullableOption stringList "Disabled TTSR rules.";
      };
      default = { };
      description = "Compaction, branch summaries, rules, and context limits.";
    };

    memory = mkOption {
      type = settingGroup {
        commonEnabled = nullableOption types.bool "Enable common memory extraction.";
        backend = enumOption [
          "off"
          "local"
          "hindsight"
          "mnemopi"
        ] "Memory backend.";
        maxRolloutsPerStartup = nullableOption types.int "Maximum memory rollouts processed at startup.";
        maxRolloutAgeDays = nullableOption types.int "Maximum rollout age.";
        minRolloutIdleHours = nullableOption types.int "Minimum rollout idle age.";
        threadScanLimit = nullableOption types.int "Memory thread scan limit.";
        summaryInjectionTokenLimit = nullableOption types.int "Memory summary injection token limit.";
      };
      default = { };
      description = "Memory enablement, backend, and common controls.";
    };

    files = mkOption {
      type = settingGroup {
        editMode = nullableOption types.str "File edit mode.";
        fuzzyMatch = nullableOption types.bool "Enable fuzzy edit matching.";
        fuzzyThreshold = nullableOption types.number "Fuzzy edit threshold.";
        streamingAbort = nullableOption types.bool "Abort streaming edits on failure.";
        blockAutoGenerated = nullableOption types.bool "Block edits to generated files.";
        enforceSeenLines = nullableOption types.bool "Gate the hashline seen-line guard.";
        readLineNumbers = nullableOption types.bool "Include line numbers in reads.";
        readHashLines = nullableOption types.bool "Include hashline identifiers in reads.";
        readDefaultLimit = nullableOption types.int "Default read line limit.";
        summarizeEnabled = nullableOption types.bool "Enable read summaries.";
        summarizeProse = nullableOption types.bool "Summarize prose files.";
        summarizeMinBodyLines = nullableOption types.int "Minimum body lines before summarization.";
        summarizeMinCommentLines = nullableOption types.int "Minimum comment lines before summarization.";
        summarizeMinTotalLines = nullableOption types.int "Minimum total lines before summarization.";
        summarizeUnfoldUntil = nullableOption types.int "Summary unfold target.";
        summarizeUnfoldLimit = nullableOption types.int "Summary unfold limit.";
        toolResultPreview = nullableOption types.int "Read tool-result preview size.";
        lspEnabled = nullableOption types.bool "Enable LSP integration.";
        lspLazy = nullableOption types.bool "Start language servers lazily.";
        lspFormatOnWrite = nullableOption types.bool "Format files after writes.";
        lspDiagnosticsOnWrite = nullableOption types.bool "Run diagnostics after writes.";
        lspDiagnosticsOnEdit = nullableOption types.bool "Run diagnostics after edits.";
        lspDiagnosticsDeduplicate = nullableOption types.bool "Deduplicate LSP diagnostics.";
      };
      default = { };
      description = "File editing, reading, summaries, and LSP controls.";
    };

    shell = mkOption {
      type = settingGroup {
        path = nullableOption types.str "Shell executable path.";
        bashEnabled = nullableOption types.bool "Enable the bash tool.";
        autoBackground = nullableOption types.bool "Automatically background long-running commands.";
        stripTrailingHeadTail = nullableOption types.bool "Strip redundant trailing head/tail filters.";
        interceptorEnabled = nullableOption types.bool "Enable bash interception rules.";
        interceptorPatterns = nullableOption json.type "Bash interception patterns.";
        evalPython = nullableOption types.bool "Enable Python eval.";
        evalJavaScript = nullableOption types.bool "Enable JavaScript eval.";
        pythonKernelMode = nullableOption types.str "Python kernel mode.";
        pythonInterpreter = nullableOption types.str "Python interpreter path.";
      };
      default = { };
      description = "Shell, bash interception, eval, and Python settings.";
    };

    tools = mkOption {
      type = settingGroup {
        approval = nullableOption json.type "Per-tool approval policy.";
        approvalMode = nullableOption types.str "Global tool approval mode.";
        artifactSpillThreshold = nullableOption types.int "Artifact spill threshold.";
        artifactHeadBytes = nullableOption types.int "Artifact head byte limit.";
        artifactTailBytes = nullableOption types.int "Artifact tail byte limit.";
        artifactTailLines = nullableOption types.int "Artifact tail line limit.";
        outputMaxColumns = nullableOption types.int "Maximum tool output columns.";
        maxTimeout = nullableOption types.int "Maximum tool timeout.";
        xdevEnabled = nullableOption types.bool "Mount rarely-used tools under xd:// device URLs.";
        intentTracing = nullableOption types.bool "Enable tool intent tracing.";
        todoEnabled = nullableOption types.bool "Enable todo tools.";
        findEnabled = nullableOption types.bool "Enable file finding.";
        searchEnabled = nullableOption types.bool "Enable text search.";
        searchContextBefore = nullableOption types.int "Search context lines before matches.";
        searchContextAfter = nullableOption types.int "Search context lines after matches.";
        astGrepEnabled = nullableOption types.bool "Enable AST grep.";
        astEditEnabled = nullableOption types.bool "Enable AST editing.";
        fetchEnabled = nullableOption types.bool "Enable URL fetching.";
        webSearchEnabled = nullableOption types.bool "Enable web search.";
        browserEnabled = nullableOption types.bool "Enable browser tools.";
        browserHeadless = nullableOption types.bool "Run browser tools headlessly.";
        browserScreenshotDir = nullableOption types.str "Browser screenshot directory.";
        githubEnabled = nullableOption types.bool "Enable GitHub tools.";
        asyncEnabled = nullableOption types.bool "Enable asynchronous tool execution.";
        asyncMaxJobs = nullableOption types.int "Maximum asynchronous jobs.";
      };
      default = { };
      description = "Tool enablement, approvals, output limits, search, browser, and execution.";
    };

    tasks = mkOption {
      type = settingGroup {
        planEnabled = nullableOption types.bool "Enable plan mode.";
        goalEnabled = nullableOption types.bool "Enable persistent goals.";
        goalStatusInFooter = nullableOption types.bool "Show goal status in the footer.";
        goalContinuationModes = nullableOption stringList "Goal continuation modes.";
        isolationMode = nullableOption types.str "Subagent isolation mode.";
        isolationMerge = nullableOption types.bool "Merge isolated subagent changes.";
        isolationCommits = nullableOption types.bool "Commit isolated subagent changes.";
        eager = nullableOption types.bool "Enable eager subagent execution.";
        batch = nullableOption types.bool "Enable batched subagent execution.";
        maxConcurrency = nullableOption types.int "Maximum subagent concurrency.";
        enableLsp = nullableOption types.bool "Enable LSP in subagents.";
        maxRecursionDepth = nullableOption types.int "Maximum subagent recursion depth.";
        maxRuntimeMs = nullableOption types.int "Maximum subagent runtime.";
        disabledAgents = nullableOption stringList "Disabled task agents.";
        agentModelOverrides = nullableOption stringMap "Per-agent model selectors.";
        showResolvedModelBadge = nullableOption types.bool "Show resolved subagent model badges.";
        skillsEnabled = nullableOption types.bool "Enable skill discovery.";
        enableSkillCommands = nullableOption types.bool "Expose skills as commands.";
        skillDirectories = nullableOption stringList "Additional skill directories.";
        ignoredSkills = nullableOption stringList "Ignored skill names.";
        includeSkills = nullableOption stringList "Explicitly included skill names.";
      };
      default = { };
      description = "Modes, subagents, isolation, commands, and skill discovery.";
    };

    providers = mkOption {
      type = settingGroup {
        disabled = nullableOption stringList "Disabled provider IDs.";
        webSearch = nullableOption types.str "Preferred web-search provider.";
        image = nullableOption types.str "Preferred image provider.";
        tinyModel = nullableOption types.str "Tiny model selector.";
        tinyModelDevice = nullableOption types.str "Tiny model device.";
        tinyModelDtype = nullableOption types.str "Tiny model data type.";
        memoryModel = nullableOption types.str "Memory model selector.";
        autoThinkingModel = nullableOption types.str "Automatic thinking classifier model.";
        kimiApiFormat = nullableOption types.str "Kimi API format.";
        openaiWebsockets = nullableOption types.bool "Prefer OpenAI websocket transport.";
        openrouterVariant = nullableOption types.str "OpenRouter provider variant.";
        fetch = nullableOption types.str "Preferred fetch service.";
        appendOnlyContext = nullableOption types.bool "Use append-only provider context.";
        secretsEnabled = nullableOption types.bool "Enable secret redaction.";
        redactSecrets = nullableOption types.bool "Redact secrets from shared sessions.";
      };
      default = { };
      description = "Provider, tiny-model, transport, service, and privacy controls.";
    };

    settings = mkOption {
      type = json.type;
      default = { };
      description = ''
        Unrestricted OMP config.yml settings. These recursively override typed options.
        Raw settings may bypass Nix-level validation.
      '';
    };

    extraConfig = mkOption {
      type = json.type;
      default = { };
      description = ''
        Legacy unrestricted config.yml overlay. This recursively overrides typed options
        and omp.settings, and may bypass Nix-level validation.
      '';
    };

    plugins = mkOption {
      type = types.attrsOf pluginType;
      default = { };
      description = ''
        Declarative OMP plugins. Entries with package set are linked into
        ~/.omp/plugins/node_modules and recorded in omp-plugins.lock.json.
      '';
    };

    modelProviders = mkOption {
      type = types.attrsOf providerType;
      default = { };
      description = "Custom, override-only, or discovery-backed models.yml providers.";
    };

    modelEquivalence = {
      overrides = mkOption {
        type = nullable stringMap;
        default = null;
        description = "Concrete model selectors mapped to canonical model IDs.";
      };
      exclude = mkOption {
        type = nullable stringList;
        default = null;
        description = "Concrete model selectors excluded from equivalence grouping.";
      };
    };

    extraModels = mkOption {
      type = json.type;
      default = { };
      description = ''
        Final unrestricted models.yml overlay. This recursively overrides generated
        providers and equivalence settings, and may bypass Nix-level validation.
      '';
    };

    keybindings = mkOption {
      type = types.attrsOf (types.either types.str stringList);
      default = { };
      description = "OMP action IDs mapped to one chord or a list of chords.";
    };

    themes = mkOption {
      type = types.attrsOf json.type;
      default = { };
      description = "Custom OMP themes written to ~/.omp/agent/themes/<name>.json.";
    };

    prompts = {
      system = mkOption {
        type = promptFileType;
        default = null;
        description = "Managed ~/.omp/agent/SYSTEM.md.";
      };
      appendSystem = mkOption {
        type = promptFileType;
        default = null;
        description = "Managed ~/.omp/agent/APPEND_SYSTEM.md.";
      };
      titleSystem = mkOption {
        type = promptFileType;
        default = null;
        description = "Managed ~/.omp/agent/TITLE_SYSTEM.md.";
      };
      agents = mkOption {
        type = promptFileType;
        default = null;
        description = "Managed ~/.omp/agent/AGENTS.md.";
      };
    };

    agentFiles = mkOption {
      type = types.attrsOf managedFileType;
      default = { };
      description = ''
        Capability files beneath ~/.omp/agent. Paths must be relative and cannot
        collide with generated configuration, themes, or dedicated prompt files.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = unsafeAgentFileNames == [ ];
        message = "omp.agentFiles paths must be non-empty, relative, and may not contain '..': ${lib.concatStringsSep ", " unsafeAgentFileNames}";
      }
      {
        assertion = collidingAgentFileNames == [ ];
        message = "omp.agentFiles entries collide with generated paths: ${lib.concatStringsSep ", " collidingAgentFileNames}";
      }
      {
        assertion = invalidManagedFiles == [ ];
        message = "omp.agentFiles entries must set exactly one of text or source: ${lib.concatStringsSep ", " invalidManagedFiles}";
      }
      {
        assertion = invalidPromptFiles == [ ];
        message = "omp.prompts entries must set exactly one of text or source: ${lib.concatStringsSep ", " invalidPromptFiles}";
      }
      {
        assertion = duplicatePluginNames == [ ];
        message = "omp.plugins entries must have unique effective names: ${lib.concatStringsSep ", " duplicatePluginNames}";
      }
      {
        assertion = unsafePluginNames == [ ];
        message = "omp.plugins names must be non-empty, relative, and may not contain '..': ${lib.concatStringsSep ", " unsafePluginNames}";
      }
      {
        assertion = providerValidationErrors == [ ];
        message = lib.concatStringsSep "\n" providerValidationErrors;
      }
    ];

    home.packages = lib.optional (cfg.package != null) cfg.package;

    sops.templates."omp-config" = {
      content = configContent;
      path = "${config.home.homeDirectory}/.omp/agent/config.yml";
    };
    sops.templates."omp-models" = {
      content = modelsContent;
      path = "${config.home.homeDirectory}/.omp/agent/models.yml";
    };

    home.file =
      lib.optionalAttrs (cfg.keybindings != { })
        {
          ".omp/agent/keybindings.yml".text = builtins.toJSON cfg.keybindings;
        }
      // generatedThemeFiles
      // generatedPromptFiles
      // generatedAgentFiles
      // generatedPluginFiles;
  };
}
