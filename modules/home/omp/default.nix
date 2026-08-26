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
    "max"
  ];

  reasoningEffortMapType = types.submodule {
    options = lib.genAttrs [
      "minimal"
      "low"
      "medium"
      "high"
      "xhigh"
      "max"
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
      advisor = cfg.advisorModel;
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
      contextLine = cfg.appearance.statusLineContextLine;
      sessionAccent = cfg.appearance.statusLineSessionAccent;
      transparent = cfg.appearance.statusLineTransparent;
      compactThinkingLevel = cfg.appearance.statusLineCompactThinkingLevel;
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
      cacheMissMarker = cfg.appearance.cacheMissMarker;
      collapseCompacted = cfg.appearance.collapseCompacted;
      hideToolActivity = cfg.appearance.hideToolActivity;
    };
    terminal = {
      showImages = cfg.appearance.showImages;
      showProgress = cfg.appearance.showProgress;
    };
    images = {
      autoResize = cfg.appearance.imageAutoResize;
      blockImages = cfg.appearance.blockImages;
      describeForTextModels = cfg.appearance.imageDescribeForTextModels;
    };
    tui = {
      maxInlineImageColumns = cfg.appearance.maxInlineImageColumns;
      maxInlineImageRows = cfg.appearance.maxInlineImageRows;
      maxInlineImages = cfg.appearance.maxInlineImages;
      textSizing = cfg.appearance.textSizing;
      hyperlinks = cfg.appearance.hyperlinks;
      renderMermaid = cfg.appearance.renderMermaid;
      resizeScrollback = cfg.appearance.resizeScrollback;
      tight = cfg.appearance.tight;
      titleState = cfg.appearance.titleState;
      imeSafeCursor = cfg.appearance.imeSafeCursor;
      codexResetFireworks = cfg.appearance.codexResetFireworks;
    };
    showHardwareCursor = cfg.appearance.showHardwareCursor;

    modelTags = cfg.model.tags;
    modelProviderOrder = cfg.model.providerOrder;
    cycleOrder = cfg.model.cycleOrder;
    defaultThinkingLevel = cfg.model.defaultThinkingLevel;
    hideThinkingBlock = cfg.model.hideThinkingBlock;
    proseOnlyThinking = cfg.model.proseOnlyThinking;
    omitThinking = cfg.model.omitThinking;
    externalThinking = cfg.model.externalThinking;
    inlineToolDescriptors =
      if cfg.model.inlineToolDescriptors != null then
        cfg.model.inlineToolDescriptors
      else if cfg.model.repeatToolDescriptions != null then
        (if cfg.model.repeatToolDescriptions then "always" else "never")
      else
        null;
    includeModelInPrompt = cfg.model.includeModelInPrompt;
    includeWorkspaceTree = cfg.model.includeWorkspaceTree;
    personality = cfg.model.personality;
    temperature = cfg.model.temperature;
    topP = cfg.model.topP;
    topK = cfg.model.topK;
    minP = cfg.model.minP;
    presencePenalty = cfg.model.presencePenalty;
    repetitionPenalty = cfg.model.repetitionPenalty;
    textVerbosity = cfg.model.textVerbosity;
    serviceTier = cfg.model.serviceTier;
    tier = {
      openai = cfg.model.tierOpenai;
      anthropic = cfg.model.tierAnthropic;
      google = cfg.model.tierGoogle;
      subagent = cfg.model.tierSubagent;
      advisor = cfg.model.tierAdvisor;
    };
    model = {
      loopGuard = {
        enabled = cfg.model.loopGuardEnabled;
        checkAssistantContent = cfg.model.loopGuardCheckAssistantContent;
        toolCallReminder = cfg.model.loopGuardToolCallReminder;
      };
      toolCallLoopGuard = {
        enabled = cfg.model.toolCallLoopGuardEnabled;
        threshold = cfg.model.toolCallLoopGuardThreshold;
        exemptTools = cfg.model.toolCallLoopGuardExemptTools;
      };
    };
    retry = {
      enabled = cfg.model.retryEnabled;
      maxRetries = cfg.model.maxRetries;
      baseDelayMs = cfg.model.retryBaseDelayMs;
      maxDelayMs = cfg.model.retryMaxDelayMs;
      modelFallback = cfg.model.modelFallback;
      fallbackChains = cfg.model.fallbackChains;
      fallbackRevertPolicy = cfg.model.fallbackRevertPolicy;
      usageAwareFallback = cfg.model.usageAwareFallback;
      usageReservePct = cfg.model.usageReservePct;
      usageReservePolicy = cfg.model.usageReservePolicy;
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
      showSplash = cfg.interaction.showSplash;
      changelogMode =
        if cfg.interaction.changelogMode != null then
          cfg.interaction.changelogMode
        else if cfg.interaction.collapseChangelog != null then
          (if cfg.interaction.collapseChangelog then "summary" else "full")
        else
          null;
    };
    completion.notify = cfg.interaction.completionNotify;
    error.notify = cfg.interaction.errorNotify;
    ask = {
      timeout = cfg.interaction.approvalTimeout;
      notify = cfg.interaction.approvalNotify;
    };
    autolearn = {
      enabled = cfg.interaction.autolearnEnabled;
      autoContinue = cfg.interaction.autolearnAutoContinue;
      minToolCalls = cfg.interaction.autolearnMinToolCalls;
    };
    spelling = {
      autocomplete = cfg.interaction.spellingAutocomplete;
      autocorrect = cfg.interaction.spellingAutocorrect;
      typoDetection = cfg.interaction.spellingTypoDetection;
    };
    paste.largeMenuThreshold = cfg.interaction.pasteLargeMenuThreshold;
    power.sleepPrevention = cfg.interaction.sleepPrevention;

    contextPromotion.enabled = cfg.context.promotionEnabled;
    extendedContext = cfg.context.extendedContext;
    compaction = {
      enabled = cfg.context.compactionEnabled;
      midTurnEnabled = cfg.context.compactionMidTurnEnabled;
      methodOrder = cfg.context.compactionMethodOrder;
      strategy = cfg.context.compactionStrategy;
      thresholdPercent = cfg.context.compactionThresholdPercent;
      thresholdTokens = cfg.context.compactionThresholdTokens;
      reserveTokens = cfg.context.compactionReserveTokens;
      keepRecentTokens = cfg.context.compactionKeepRecentTokens;
      autoContinue = cfg.context.compactionAutoContinue;
      supersedeReads = cfg.context.compactionSupersedeReads;
      dropUseless = cfg.context.compactionDropUseless;
      handoffSaveToDisk = cfg.context.compactionHandoffSaveToDisk;
      remoteStreamingV2Enabled = cfg.context.compactionRemoteStreamingV2Enabled;
      asyncEnabled = cfg.context.compactionAsyncEnabled;
      remoteEndpoint = cfg.context.compactionRemoteEndpoint;
      v2RetainedMessageBudget = cfg.context.compactionV2RetainedMessageBudget;
      idleEnabled = cfg.context.compactionIdleEnabled;
      idleThresholdTokens = cfg.context.compactionIdleThresholdTokens;
      idleTimeoutSeconds = cfg.context.compactionIdleTimeoutSeconds;
    };
    snapcompact = {
      shape = cfg.context.snapcompactShape;
      systemPrompt = cfg.context.snapcompactSystemPrompt;
      toolResults = cfg.context.snapcompactToolResults;
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
      fallbackTokenLimit = cfg.memory.memoriesFallbackTokenLimit;
      maxRawMemoriesForGlobal = cfg.memory.memoriesMaxRawMemoriesForGlobal;
      phase1InputTokenLimit = cfg.memory.memoriesPhase1InputTokenLimit;
      phase2HeartbeatSeconds = cfg.memory.memoriesPhase2HeartbeatSeconds;
      phase2LeaseSeconds = cfg.memory.memoriesPhase2LeaseSeconds;
      phase2RetryDelaySeconds = cfg.memory.memoriesPhase2RetryDelaySeconds;
      rolloutPayloadPercent = cfg.memory.memoriesRolloutPayloadPercent;
      stage1Concurrency = cfg.memory.memoriesStage1Concurrency;
      stage1LeaseSeconds = cfg.memory.memoriesStage1LeaseSeconds;
      stage1RetryDelaySeconds = cfg.memory.memoriesStage1RetryDelaySeconds;
    };
    memory.backend = cfg.memory.backend;

    edit = {
      mode = cfg.files.editMode;
      fuzzyMatch = cfg.files.fuzzyMatch;
      fuzzyThreshold = cfg.files.fuzzyThreshold;
      streamingAbort = cfg.files.streamingAbort;
      blockAutoGenerated = cfg.files.blockAutoGenerated;
      enforceSeenLines = cfg.files.enforceSeenLines;
      autoRepair.enabled = cfg.files.editAutoRepairEnabled;
      blackbox.enabled = cfg.files.editBlackboxEnabled;
    };
    readLineNumbers = cfg.files.readLineNumbers;
    read = {
      defaultLimit = cfg.files.readDefaultLimit;
      renderMarkdown = cfg.files.readRenderMarkdown;
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
      shared = cfg.files.lspShared;
      formatOnWrite = cfg.files.lspFormatOnWrite;
      diagnosticsOnWrite = cfg.files.lspDiagnosticsOnWrite;
      diagnosticsOnEdit = cfg.files.lspDiagnosticsOnEdit;
      diagnosticsDeduplicate = cfg.files.lspDiagnosticsDeduplicate;
    };

    shellPath = cfg.shell.path;
    bash = {
      enabled = cfg.shell.bashEnabled;
      autoBackground.enabled = cfg.shell.autoBackground;
      autoBackground.thresholdMs = cfg.shell.bashAutoBackgroundThresholdMs;
      direnv = cfg.shell.bashDirenv;
      direnvLoadTimeoutMs = cfg.shell.bashDirenvLoadTimeoutMs;
      patterns = cfg.shell.bashPatterns;
    };
    bashInterceptor = {
      enabled = cfg.shell.interceptorEnabled;
      patterns = cfg.shell.interceptorPatterns;
    };
    shellMinimizer = {
      enabled = cfg.shell.shellMinimizerEnabled;
      except = cfg.shell.shellMinimizerExcept;
      only = cfg.shell.shellMinimizerOnly;
      maxCaptureBytes = cfg.shell.shellMinimizerMaxCaptureBytes;
      sourceOutlineLevel = cfg.shell.shellMinimizerSourceOutlineLevel;
    };
    eval = {
      py = cfg.shell.evalPython;
      js = cfg.shell.evalJavaScript;
      jl = cfg.shell.evalJulia;
      rb = cfg.shell.evalRuby;
      autoBackground = {
        enabled = cfg.shell.evalAutoBackgroundEnabled;
        thresholdMs = cfg.shell.evalAutoBackgroundThresholdMs;
      };
    };
    python = {
      kernelMode = cfg.shell.pythonKernelMode;
      interpreter = cfg.shell.pythonInterpreter;
    };
    julia.interpreter = cfg.shell.juliaInterpreter;
    ruby.interpreter = cfg.shell.rubyInterpreter;

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
      xdevDocs = cfg.tools.xdevDocs;
      xdevInlineDevices = cfg.tools.xdevInlineDevices;
      intentTracing = cfg.tools.intentTracing;
      abortOnFabricatedResult = cfg.tools.abortOnFabricatedResult;
      format = cfg.tools.format;
    };
    todo = {
      enabled = cfg.tools.todoEnabled;
      reminders = cfg.tools.todoReminders;
      remindersMax = cfg.tools.todoRemindersMax;
      eager = cfg.tools.todoEager;
    };
    glob.enabled =
      if cfg.tools.globEnabled != null then
        cfg.tools.globEnabled
      else
        cfg.tools.findEnabled;
    grep = {
      enabled =
        if cfg.tools.grepEnabled != null then
          cfg.tools.grepEnabled
        else
          cfg.tools.searchEnabled;
      contextBefore =
        if cfg.tools.grepContextBefore != null then
          cfg.tools.grepContextBefore
        else
          cfg.tools.searchContextBefore;
      contextAfter =
        if cfg.tools.grepContextAfter != null then
          cfg.tools.grepContextAfter
        else
          cfg.tools.searchContextAfter;
    };
    astGrep.enabled = cfg.tools.astGrepEnabled;
    astEdit.enabled = cfg.tools.astEditEnabled;
    launch.enabled = cfg.tools.launchEnabled;
    debug.enabled = cfg.tools.debugEnabled;
    computer = {
      enabled = cfg.tools.computerEnabled;
      display = cfg.tools.computerDisplay;
      maxWidth = cfg.tools.computerMaxWidth;
      maxHeight = cfg.tools.computerMaxHeight;
    };
    speechgen.enabled = cfg.tools.speechgenEnabled;
    generate_image.enabled = cfg.tools.generateImageEnabled;
    inspect_image = {
      enabled = cfg.tools.inspectImageEnabled;
      mode = cfg.tools.inspectImageMode;
      timeoutMs = cfg.tools.inspectImageTimeoutMs;
    };
    checkpoint.enabled = cfg.tools.checkpointEnabled;
    vault.enabled = cfg.tools.vaultEnabled;
    security.enabled = cfg.tools.securityEnabled;
    fetch.enabled = cfg.tools.fetchEnabled;
    web_search.enabled =
      if cfg.tools.webSearchEnabled != null then
        cfg.tools.webSearchEnabled
      else
        null;
    browser = {
      enabled = cfg.tools.browserEnabled;
      headless = cfg.tools.browserHeadless;
      screenshotDir = cfg.tools.browserScreenshotDir;
      cdpUrl = cfg.tools.browserCdpUrl;
      relay = cfg.tools.browserRelay;
      relayUrl = cfg.tools.browserRelayUrl;
      cmux = cfg.tools.browserCmux;
    };
    github = {
      enabled = cfg.tools.githubEnabled;
      cache = {
        enabled = cfg.tools.githubCacheEnabled;
        softTtlSec = cfg.tools.githubCacheSoftTtlSec;
        hardTtlSec = cfg.tools.githubCacheHardTtlSec;
      };
    };
    async = {
      enabled = cfg.tools.asyncEnabled;
      maxJobs = cfg.tools.asyncMaxJobs;
      pollWaitDuration = cfg.tools.asyncPollWaitDuration;
    };

    plan = {
      enabled = cfg.tasks.planEnabled;
      defaultOnStartup = cfg.tasks.planDefaultOnStartup;
    };
    prewalk.enabled = cfg.tasks.prewalkEnabled;
    advisor = {
      enabled = cfg.tasks.advisorEnabled;
      syncBacklog = cfg.tasks.advisorSyncBacklog;
      immuneTurns = cfg.tasks.advisorImmuneTurns;
    };
    goal = {
      enabled = cfg.tasks.goalEnabled;
      statusInFooter = cfg.tasks.goalStatusInFooter;
      continuationModes = cfg.tasks.goalContinuationModes;
    };
    task = {
      isolation = {
        mode = cfg.tasks.isolationMode;
        apply = cfg.tasks.isolationApply;
        merge = cfg.tasks.isolationMerge;
        commits = cfg.tasks.isolationCommits;
      };
      eager = cfg.tasks.taskEager;
      batch = cfg.tasks.batch;
      maxConcurrency = cfg.tasks.maxConcurrency;
      enableLsp = cfg.tasks.enableLsp;
      enableEffort = cfg.tasks.taskEnableEffort;
      maxEffort = cfg.tasks.taskMaxEffort;
      maxRecursionDepth = cfg.tasks.maxRecursionDepth;
      maxRuntimeMs = cfg.tasks.maxRuntimeMs;
      disabledAgents = cfg.tasks.disabledAgents;
      agentModelOverrides = cfg.tasks.agentModelOverrides;
      agentPrewalk = cfg.tasks.taskAgentPrewalk;
      agentAdvisor = cfg.tasks.taskAgentAdvisor;
      prewalk = cfg.tasks.taskPrewalk;
      showResolvedModelBadge = cfg.tasks.showResolvedModelBadge;
      softRequestBudget = cfg.tasks.taskSoftRequestBudget;
      softRequestBudgetNotice = cfg.tasks.taskSoftRequestBudgetNotice;
      agentIdleTtlMs = cfg.tasks.taskAgentIdleTtlMs;
    };
    tasks.todoClearDelay = cfg.tasks.todoClearDelay;
    skills = {
      enabled = cfg.tasks.skillsEnabled;
      enableSkillCommands = cfg.tasks.enableSkillCommands;
      customDirectories = cfg.tasks.skillDirectories;
      ignoredSkills = cfg.tasks.ignoredSkills;
      includeSkills = cfg.tasks.includeSkills;
      enableAgentsUser = cfg.tasks.skillsEnableAgentsUser;
      enableAgentsProject = cfg.tasks.skillsEnableAgentsProject;
      enableClaudeUser = cfg.tasks.skillsEnableClaudeUser;
      enableClaudeProject = cfg.tasks.skillsEnableClaudeProject;
      enableCodexUser = cfg.tasks.skillsEnableCodexUser;
      enablePiUser = cfg.tasks.skillsEnablePiUser;
      enablePiProject = cfg.tasks.skillsEnablePiProject;
    };
    commands = {
      enableClaudeUser = cfg.tasks.commandsEnableClaudeUser;
      enableClaudeProject = cfg.tasks.commandsEnableClaudeProject;
      enableOpencodeUser = cfg.tasks.commandsEnableOpencodeUser;
      enableOpencodeProject = cfg.tasks.commandsEnableOpencodeProject;
    };
    worktree.base = cfg.tasks.worktreeBase;
    workspace.additionalDirectories = cfg.tasks.workspaceAdditionalDirectories;

    disabledProviders = cfg.providers.disabled;
    providers = {
      webSearchOrder =
        if cfg.providers.webSearchOrder != null then
          cfg.providers.webSearchOrder
        else if cfg.providers.webSearch != null then
          [ cfg.providers.webSearch ]
        else
          null;
      webSearchExclude = cfg.providers.webSearchExclude;
      webSearchTimeoutSeconds = cfg.providers.webSearchTimeoutSeconds;
      webSearchGeminiModel = cfg.providers.webSearchGeminiModel;
      imageOrder =
        if cfg.providers.imageOrder != null then
          cfg.providers.imageOrder
        else if cfg.providers.image != null then
          [ cfg.providers.image ]
        else
          null;
      antigravityEndpoint = cfg.providers.antigravityEndpoint;
      fireworksTier = cfg.providers.fireworksTier;
      cacheRetention = cfg.providers.cacheRetention;
      maxInFlightRequests = cfg.providers.maxInFlightRequests;
      anthropic.serverSideFallback = cfg.providers.anthropicServerSideFallback;
      openai-codex.codeMode = cfg.providers.openaiCodexCodeMode;
      openai-codex.codeModeDirectTools = cfg.providers.openaiCodexCodeModeDirectTools;
      ollama-cloud.maxConcurrency = cfg.providers.ollamaCloudMaxConcurrency;
      tinyModel = cfg.providers.tinyModel;
      tinyModelDevice = cfg.providers.tinyModelDevice;
      tinyModelDtype = cfg.providers.tinyModelDtype;
      memoryModel = cfg.providers.memoryModel;
      autoThinkingModel = cfg.providers.autoThinkingModel;
      autoThinkingMaxEffort = cfg.providers.autoThinkingMaxEffort;
      unexpectedStopModel = cfg.providers.unexpectedStopModel;
      kimiApiFormat = cfg.providers.kimiApiFormat;
      openaiWebsockets = cfg.providers.openaiWebsockets;
      openrouterVariant = cfg.providers.openrouterVariant;
      fetch = cfg.providers.fetch;
    };
    provider.appendOnlyContext = cfg.providers.appendOnlyContext;
    secrets.enabled = cfg.providers.secretsEnabled;
    share = {
      redactSecrets = cfg.providers.redactSecrets;
      serverUrl = cfg.providers.shareServerUrl;
      store = cfg.providers.shareStore;
    };
    codexResets = {
      autoRedeem = cfg.providers.codexResetsAutoRedeem;
      minBlockedMinutes = cfg.providers.codexResetsMinBlockedMinutes;
      keepCredits = cfg.providers.codexResetsKeepCredits;
      salvageHorizonHours = cfg.providers.codexResetsSalvageHorizonHours;
    };
    tts = {
      localModel = cfg.providers.ttsLocalModel;
      localVoice = cfg.providers.ttsLocalVoice;
    };
    speech = {
      enabled = cfg.providers.speechEnabled;
      enhanced = cfg.providers.speechEnhanced;
      mode = cfg.providers.speechMode;
      voice = cfg.providers.speechVoice;
    };
    stt = {
      enabled = cfg.providers.sttEnabled;
      language = cfg.providers.sttLanguage;
      modelName = cfg.providers.sttModelName;
      submitTrigger = cfg.providers.sttSubmitTrigger;
    };
    recap = {
      enabled = cfg.providers.recapEnabled;
      idleSeconds = cfg.providers.recapIdleSeconds;
    };
    collab = {
      displayName = cfg.providers.collabDisplayName;
      relayUrl = cfg.providers.collabRelayUrl;
      webUrl = cfg.providers.collabWebUrl;
    };
    dev = {
      autoqa = cfg.providers.devAutoqa;
      autoqaConsent = cfg.providers.devAutoqaConsent;
      autoqaPush = {
        endpoint = cfg.providers.devAutoqaPushEndpoint;
        token = cfg.providers.devAutoqaPushToken;
      };
    };
    exa = {
      enabled = cfg.providers.exaEnabled;
      searchDelayMs = cfg.providers.exaSearchDelayMs;
    };
    thinkingBudgets = cfg.providers.thinkingBudgets;
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
            ) "omp.modelProviders.''${name}.apiKey is required unless auth = \"none\"."
          ++ lib.optional
            (
              hasModels && modelsMissingApi
            ) "omp.modelProviders.''${name} must set api or set api on every model."
          ++ lib.optional
            (
              !hasModels && !hasOverride
            ) "omp.modelProviders.''${name} must configure models or at least one provider override."
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
    advisorModel = nullableOption types.str "OMP model selector used for the advisor subagent.";
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
        statusLineContextLine = enumOption [
          "embedded"
          "none"
          "separate"
        ] "How context usage is rendered on the status line.";
        statusLineSessionAccent = nullableOption types.bool "Use session name color for editor border.";
        statusLineTransparent = nullableOption types.bool "Use a transparent status line.";
        statusLineCompactThinkingLevel = nullableOption types.bool "Show thinking level as a compact icon.";
        statusLineShowHookStatus = nullableOption types.bool "Show hook status.";
        statusLineLeftSegments = nullableOption stringList "Left status line segments.";
        statusLineRightSegments = nullableOption stringList "Right status line segments.";
        statusLineSegmentOptions = nullableOption json.type "Per-segment status line options.";
        tabWidth = nullableOption types.int "Display tab width.";
        shimmer = enumOption [
          "classic"
          "dots"
          "bar"
          "off"
        ] "Animation style for loading messages.";
        smoothStreaming = nullableOption types.bool "Enable smooth streamed rendering.";
        showTokenUsage = nullableOption types.bool "Show token usage.";
        cacheMissMarker = nullableOption types.bool "Show cache miss markers in transcript.";
        collapseCompacted = nullableOption types.bool "Collapse pre-compaction history behind a summary divider.";
        hideToolActivity = nullableOption types.bool "Hide model-initiated tool calls and results.";
        showImages = nullableOption types.bool "Render terminal images.";
        showProgress = nullableOption types.bool "Emit OSC 9;4 progress indicator.";
        imageAutoResize = nullableOption types.bool "Resize images automatically.";
        blockImages = nullableOption types.bool "Block image input.";
        imageDescribeForTextModels = nullableOption types.bool "Describe images with a vision model for text models.";
        maxInlineImageColumns = nullableOption types.int "Maximum inline image width.";
        maxInlineImageRows = nullableOption types.int "Maximum inline image height.";
        maxInlineImages = nullableOption types.int "Maximum number of inline images.";
        textSizing = nullableOption types.bool "Enable terminal text sizing.";
        hyperlinks = enumOption [
          "auto"
          "always"
          "off"
        ] "Terminal hyperlink mode.";
        renderMermaid = nullableOption types.bool "Render Mermaid code blocks as ASCII diagrams.";
        resizeScrollback = enumOption [
          "rebuild"
          "static"
          "off"
        ] "Scrollback refresh behavior on terminal resize.";
        tight = nullableOption types.bool "Remove 1-character horizontal padding from output.";
        titleState = nullableOption types.bool "Show agent run state in terminal title.";
        imeSafeCursor = nullableOption types.bool "Move prompt bottom border for IME support.";
        codexResetFireworks = nullableOption types.bool "Celebrate unscheduled Codex usage resets.";
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
            (types.enum [
              "off"
              "auto"
            ])
          ]) "Default thinking level.";
        hideThinkingBlock = nullableOption types.bool "Hide model thinking blocks.";
        proseOnlyThinking = nullableOption types.bool "Omit code blocks from thinking summaries.";
        omitThinking = nullableOption types.bool "Instruct providers to omit thinking summaries.";
        externalThinking = nullableOption types.bool "Use private scratchpad instead of provider thinking.";
        repeatToolDescriptions = nullableOption types.bool "Repeat tool descriptions in prompts (legacy).";
        inlineToolDescriptors = enumOption [
          "auto"
          "always"
          "never"
        ] "Render tool descriptors in system prompt.";
        includeModelInPrompt = nullableOption types.bool "Include the model identity in prompts.";
        includeWorkspaceTree = nullableOption types.bool "Include workspace tree in prompts.";
        personality = nullableOption types.str "Prompt personality.";
        temperature = nullableOption types.number "Sampling temperature.";
        topP = nullableOption types.number "Top-p sampling value.";
        topK = nullableOption types.number "Top-k sampling value.";
        minP = nullableOption types.number "Minimum-p sampling value.";
        presencePenalty = nullableOption types.number "Presence penalty.";
        repetitionPenalty = nullableOption types.number "Repetition penalty.";
        textVerbosity = enumOption [
          "low"
          "medium"
          "high"
        ] "Response verbosity.";
        serviceTier = nullableOption types.str "Provider service tier (legacy).";
        tierOpenai = enumOption [
          "none"
          "default"
          "priority"
          "flex"
        ] "OpenAI service tier.";
        tierAnthropic = enumOption [
          "none"
          "standard"
          "priority"
        ] "Anthropic service tier (fast mode).";
        tierGoogle = enumOption [
          "none"
          "standard"
          "priority"
        ] "Google Gemini service tier.";
        tierSubagent = enumOption [
          "inherit"
          "none"
          "standard"
          "priority"
        ] "Subagent service tier.";
        tierAdvisor = enumOption [
          "inherit"
          "none"
          "standard"
          "priority"
        ] "Advisor service tier.";
        loopGuardEnabled = nullableOption types.bool "Enable stream loop detection.";
        loopGuardCheckAssistantContent = nullableOption types.bool "Apply loop guard to assistant prose.";
        loopGuardToolCallReminder = nullableOption types.bool "Inject tool call reminder on Gemini loops.";
        toolCallLoopGuardEnabled = nullableOption types.bool "Detect consecutive identical tool calls.";
        toolCallLoopGuardThreshold = nullableOption types.int "Consecutive identical tool call threshold.";
        toolCallLoopGuardExemptTools = nullableOption stringList "Tools exempt from loop guard.";
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
          "cooldown-expiry"
        ] "Fallback reversion policy.";
        usageAwareFallback = nullableOption types.bool "Use coding-plan quota reports to prefer fallbacks.";
        usageReservePct = nullableOption types.int "Coding-plan reserve threshold percentage.";
        usageReservePolicy = enumOption [
          "confirm"
          "auto"
          "never"
        ] "Action when coding plan is in reserve margin.";
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
        showSplash = nullableOption types.bool "Show full animated setup splash on startup.";
        completionNotify = nullableOption types.bool "Notify when generation completes.";
        errorNotify = enumOption [
          "off"
          "on"
        ] "Notify when agent stops with an error.";
        approvalTimeout = nullableOption types.int "Approval timeout in seconds.";
        approvalNotify = nullableOption types.bool "Notify when approval is required.";
        collapseChangelog = nullableOption types.bool "Collapse startup changelog output (legacy).";
        changelogMode = enumOption [
          "summary"
          "full"
          "hidden"
        ] "Startup changelog display mode.";
        autolearnEnabled = nullableOption types.bool "Nudge agent to capture lessons after stop.";
        autolearnAutoContinue = nullableOption types.bool "Auto-run private capture turn at stop.";
        autolearnMinToolCalls = nullableOption types.int "Minimum tool calls before autolearn nudging.";
        spellingAutocomplete = nullableOption types.bool "Show dictionary word completions as hints.";
        spellingAutocorrect = nullableOption types.bool "Apply macOS spelling corrections.";
        spellingTypoDetection = nullableOption types.bool "Mark misspelled prompt words.";
        pasteLargeMenuThreshold = nullableOption types.int "Line threshold to offer large-paste menu.";
        sleepPrevention = enumOption [
          "idle"
          "active"
          "always"
          "off"
        ] "Prevent macOS sleep during sessions.";
      };
      default = { };
      description = "Input, approvals, notifications, and startup settings.";
    };

    context = mkOption {
      type = settingGroup {
        promotionEnabled = nullableOption types.bool "Enable context-window model promotion.";
        extendedContext = nullableOption types.bool "Use premium long-context windows.";
        compactionEnabled = nullableOption types.bool "Enable context compaction.";
        compactionMidTurnEnabled = nullableOption types.bool "Check compaction thresholds at mid-turn tool loops.";
        compactionMethodOrder = nullableOption stringList "Preferred fallback order for context compaction.";
        compactionStrategy = nullableOption types.str "Compaction strategy.";
        compactionThresholdPercent = nullableOption types.number "Compaction threshold percentage.";
        compactionThresholdTokens = nullableOption types.int "Compaction threshold token count.";
        compactionReserveTokens = nullableOption types.int "Tokens reserved during compaction.";
        compactionKeepRecentTokens = nullableOption types.int "Recent tokens retained during compaction.";
        compactionAutoContinue = nullableOption types.bool "Continue automatically after compaction.";
        compactionSupersedeReads = nullableOption types.bool "Supersede redundant read results.";
        compactionDropUseless = nullableOption types.bool "Drop low-value context during compaction.";
        compactionHandoffSaveToDisk = nullableOption types.bool "Save generated handoff documents to markdown files.";
        compactionRemoteStreamingV2Enabled = nullableOption types.bool "Use Responses streaming compaction for remote models.";
        compactionAsyncEnabled = nullableOption types.bool "Speculatively summarize in the background.";
        compactionRemoteEndpoint = nullableOption types.str "Remote endpoint for compaction.";
        compactionV2RetainedMessageBudget = nullableOption types.int "Retained message budget for v2 compaction.";
        compactionIdleEnabled = nullableOption types.bool "Compact context while idle.";
        compactionIdleThresholdTokens = nullableOption types.int "Idle compaction token threshold.";
        compactionIdleTimeoutSeconds = nullableOption types.int "Idle compaction timeout in seconds.";
        snapcompactShape = enumOption [
          "auto"
          "compact"
          "detailed"
        ] "Frame shape snapcompact prints text with.";
        snapcompactSystemPrompt = enumOption [
          "none"
          "png"
          "compact"
        ] "Render system prompt as dense image.";
        snapcompactToolResults = nullableOption types.bool "Render large historical tool results as dense images.";
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
        memoriesFallbackTokenLimit = nullableOption types.int "Fallback token limit for memory extraction.";
        memoriesMaxRawMemoriesForGlobal = nullableOption types.int "Maximum raw memories for global consolidation.";
        memoriesPhase1InputTokenLimit = nullableOption types.int "Phase 1 input token limit.";
        memoriesPhase2HeartbeatSeconds = nullableOption types.int "Phase 2 heartbeat interval.";
        memoriesPhase2LeaseSeconds = nullableOption types.int "Phase 2 lease duration.";
        memoriesPhase2RetryDelaySeconds = nullableOption types.int "Phase 2 retry delay.";
        memoriesRolloutPayloadPercent = nullableOption types.number "Rollout payload percentage.";
        memoriesStage1Concurrency = nullableOption types.int "Stage 1 concurrency.";
        memoriesStage1LeaseSeconds = nullableOption types.int "Stage 1 lease duration.";
        memoriesStage1RetryDelaySeconds = nullableOption types.int "Stage 1 retry delay.";
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
        blockAutoGenerated = nullableOption types.bool "Prevent editing of generated files.";
        enforceSeenLines = nullableOption types.bool "Gate the hashline seen-line guard.";
        editAutoRepairEnabled = nullableOption types.bool "Ask smol model to repair broken AST edits.";
        editBlackboxEnabled = nullableOption types.bool "Append full before/after source on AST edit failure.";
        readLineNumbers = nullableOption types.bool "Include line numbers in reads.";
        readHashLines = nullableOption types.bool "Include hashline identifiers in reads (legacy).";
        readDefaultLimit = nullableOption types.int "Default read line limit.";
        readRenderMarkdown = nullableOption types.bool "Render markdown read results as formatted terminal previews.";
        summarizeEnabled = nullableOption types.bool "Enable read summaries.";
        summarizeProse = nullableOption types.bool "Summarize prose files.";
        summarizeMinBodyLines = nullableOption types.int "Minimum body lines before summarization.";
        summarizeMinCommentLines = nullableOption types.int "Minimum comment lines before summarization.";
        summarizeMinTotalLines = nullableOption types.int "Minimum total lines before summarization.";
        summarizeUnfoldUntil = nullableOption types.int "Summary unfold target.";
        summarizeUnfoldLimit = nullableOption types.int "Summary unfold limit.";
        toolResultPreview = nullableOption types.bool "Read tool-result preview in transcript.";
        lspEnabled = nullableOption types.bool "Enable LSP integration.";
        lspLazy = nullableOption types.bool "Start language servers lazily.";
        lspShared = nullableOption types.bool "Share LSP instances across sessions.";
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
        bashAutoBackgroundThresholdMs = nullableOption types.int "Bash auto-background threshold in ms.";
        bashDirenv = enumOption [
          "auto"
          "on"
          "off"
        ] "Auto-load repo direnv/devenv in bash.";
        bashDirenvLoadTimeoutMs = nullableOption types.int "Max wait for direnv export.";
        bashPatterns = nullableOption json.type "Ordered bash command approval rules.";
        stripTrailingHeadTail = nullableOption types.bool "Strip redundant trailing head/tail filters (legacy).";
        interceptorEnabled = nullableOption types.bool "Enable bash interception rules.";
        interceptorPatterns = nullableOption json.type "Bash interception patterns.";
        shellMinimizerEnabled = nullableOption types.bool "Compress verbose shell output.";
        shellMinimizerExcept = nullableOption stringList "Commands exempt from shell output compression.";
        shellMinimizerOnly = nullableOption stringList "Only compress shell output for matching commands.";
        shellMinimizerMaxCaptureBytes = nullableOption types.int "Maximum raw capture bytes before compression.";
        shellMinimizerSourceOutlineLevel = enumOption [
          "default"
          "aggressive"
          "off"
        ] "Source outline mode.";
        evalPython = nullableOption types.bool "Enable Python eval.";
        evalJavaScript = nullableOption types.bool "Enable JavaScript eval.";
        evalJulia = nullableOption types.bool "Enable Julia eval.";
        evalRuby = nullableOption types.bool "Enable Ruby eval.";
        evalAutoBackgroundEnabled = nullableOption types.bool "Auto-background long-running eval cells.";
        evalAutoBackgroundThresholdMs = nullableOption types.int "Eval auto-background threshold in ms.";
        pythonKernelMode = nullableOption types.str "Python kernel mode.";
        pythonInterpreter = nullableOption types.str "Python interpreter path.";
        juliaInterpreter = nullableOption types.str "Julia interpreter path.";
        rubyInterpreter = nullableOption types.str "Ruby interpreter path.";
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
        xdevDocs = enumOption [
          "builtins"
          "catalog"
          "all"
        ] "XD prompt documentation level.";
        xdevInlineDevices = nullableOption stringList "Dynamic devices to inline in XD docs.";
        intentTracing = nullableOption types.bool "Enable tool intent tracing.";
        abortOnFabricatedResult = nullableOption types.bool "Stop model on fabricated tool result mid-turn.";
        format = enumOption [
          "auto"
          "native"
          "glm"
          "qwen"
        ] "Tool call exposure format.";
        todoEnabled = nullableOption types.bool "Enable todo tools.";
        todoReminders = nullableOption types.bool "Remind agent to complete todos before stopping.";
        todoRemindersMax = nullableOption types.int "Maximum todo reminders before giving up.";
        todoEager = enumOption [
          "default"
          "eager"
          "off"
        ] "How strongly to push automatic todo-list creation.";
        globEnabled = nullableOption types.bool "Enable glob-based file lookup.";
        findEnabled = nullableOption types.bool "Enable file finding (legacy alias for glob).";
        grepEnabled = nullableOption types.bool "Enable regex content search.";
        grepContextBefore = nullableOption types.int "Lines of context before each grep match.";
        grepContextAfter = nullableOption types.int "Lines of context after each grep match.";
        searchEnabled = nullableOption types.bool "Enable text search (legacy alias for grep).";
        searchContextBefore = nullableOption types.int "Search context lines before matches (legacy).";
        searchContextAfter = nullableOption types.int "Search context lines after matches (legacy).";
        astGrepEnabled = nullableOption types.bool "Enable AST grep.";
        astEditEnabled = nullableOption types.bool "Enable AST editing.";
        launchEnabled = nullableOption types.bool "Enable project process supervisor tool.";
        debugEnabled = nullableOption types.bool "Enable DAP debug tool.";
        computerEnabled = nullableOption types.bool "Enable host desktop control tool.";
        computerDisplay = nullableOption types.str "Desktop control display ID or 'all'.";
        computerMaxWidth = nullableOption types.int "Desktop control max composite screenshot width.";
        computerMaxHeight = nullableOption types.int "Desktop control max composite screenshot height.";
        speechgenEnabled = nullableOption types.bool "Enable speech synthesis tool.";
        generateImageEnabled = nullableOption types.bool "Enable image generation tool.";
        inspectImageEnabled = nullableOption types.bool "Enable image inspection tool.";
        inspectImageMode = enumOption [
          "auto"
          "on"
          "off"
        ] "Image inspection mode.";
        inspectImageTimeoutMs = nullableOption types.int "Image inspection timeout in ms.";
        checkpointEnabled = nullableOption types.bool "Enable checkpoint and rewind tools.";
        vaultEnabled = nullableOption types.bool "Enable vault:// Obsidian integration.";
        securityEnabled = nullableOption types.bool "Enable security scan tools and security://.";
        fetchEnabled = nullableOption types.bool "Enable URL fetching.";
        webSearchEnabled = nullableOption types.bool "Enable web search.";
        browserEnabled = nullableOption types.bool "Enable browser tools.";
        browserHeadless = nullableOption types.bool "Run browser tools headlessly.";
        browserScreenshotDir = nullableOption types.str "Browser screenshot directory.";
        browserCdpUrl = nullableOption types.str "Browser CDP endpoint.";
        browserRelay = nullableOption types.bool "Drive user Chrome tabs via browser relay.";
        browserRelayUrl = nullableOption types.str "Browser relay endpoint.";
        browserCmux = nullableOption types.bool "Use cmux WKWebView surfaces for browser.";
        githubEnabled = nullableOption types.bool "Enable GitHub tools.";
        githubCacheEnabled = nullableOption types.bool "Cache rendered GitHub issue/PR output.";
        githubCacheSoftTtlSec = nullableOption types.int "Soft TTL for GitHub cache in seconds.";
        githubCacheHardTtlSec = nullableOption types.int "Hard TTL for GitHub cache in seconds.";
        asyncEnabled = nullableOption types.bool "Enable asynchronous tool execution.";
        asyncMaxJobs = nullableOption types.int "Maximum asynchronous jobs.";
        asyncPollWaitDuration = enumOption [
          "smart"
          "5s"
          "10s"
          "30s"
          "60s"
        ] "Hub wait duration.";
      };
      default = { };
      description = "Tool enablement, approvals, output limits, search, browser, and execution.";
    };

    tasks = mkOption {
      type = settingGroup {
        planEnabled = nullableOption types.bool "Enable plan mode.";
        planDefaultOnStartup = nullableOption types.bool "Start in plan mode by default.";
        prewalkEnabled = nullableOption types.bool "Enable prewalk from active model to cheap model.";
        advisorEnabled = nullableOption types.bool "Enable advisor model pairing.";
        advisorSyncBacklog = enumOption [
          "off"
          "1"
          "2"
          "3"
          "5"
        ] "Advisor sync backlog threshold.";
        advisorImmuneTurns = nullableOption types.int "Advisor immune turns after interrupt.";
        goalEnabled = nullableOption types.bool "Enable persistent goals.";
        goalStatusInFooter = nullableOption types.bool "Show goal status in the footer.";
        goalContinuationModes = nullableOption stringList "Goal continuation modes.";
        isolationMode = nullableOption types.str "Subagent isolation mode.";
        isolationApply = nullableOption types.bool "Apply isolated subagent changes.";
        isolationMerge = nullableOption types.str "Merge strategy for isolated subagent changes.";
        isolationCommits = nullableOption types.str "Commit message style for isolated subagent changes.";
        eager = nullableOption types.bool "Enable eager subagent execution (legacy).";
        taskEager = enumOption [
          "default"
          "eager"
          "off"
        ] "How strongly to push delegating work to subagents.";
        batch = nullableOption types.bool "Enable batched subagent execution.";
        maxConcurrency = nullableOption types.int "Maximum subagent concurrency.";
        enableLsp = nullableOption types.bool "Enable LSP in subagents.";
        taskEnableEffort = nullableOption types.bool "Expose effort parameter on task spawns.";
        taskMaxEffort = enumOption [
          "max"
          "xhigh"
          "high"
          "medium"
          "low"
          "minimal"
        ] "Max reasoning effort for subagents.";
        maxRecursionDepth = nullableOption types.int "Maximum subagent recursion depth.";
        maxRuntimeMs = nullableOption types.int "Maximum subagent runtime.";
        disabledAgents = nullableOption stringList "Disabled task agents.";
        agentModelOverrides = nullableOption stringMap "Per-agent model selectors.";
        taskAgentPrewalk = nullableOption json.type "Per-agent prewalk configurations.";
        taskAgentAdvisor = nullableOption json.type "Per-agent advisor configurations.";
        taskPrewalk = nullableOption types.bool "Arm prewalk for bundled generic task subagent.";
        showResolvedModelBadge = nullableOption types.bool "Show resolved subagent model badges.";
        taskSoftRequestBudget = nullableOption types.int "Soft request budget per subagent.";
        taskSoftRequestBudgetNotice = nullableOption types.bool "Inject steering notice when crossing soft budget.";
        taskAgentIdleTtlMs = nullableOption types.int "Subagent memory idle TTL in ms before parking.";
        todoClearDelay = nullableOption types.int "Delay in seconds before removing cleared todos.";
        skillsEnabled = nullableOption types.bool "Enable skill discovery.";
        enableSkillCommands = nullableOption types.bool "Expose skills as commands.";
        skillDirectories = nullableOption stringList "Additional skill directories.";
        ignoredSkills = nullableOption stringList "Ignored skill names.";
        includeSkills = nullableOption stringList "Explicitly included skill names.";
        skillsEnableAgentsUser = nullableOption types.bool "Load skills from ~/.agents/skills.";
        skillsEnableAgentsProject = nullableOption types.bool "Load skills from .agents/skills.";
        skillsEnableClaudeUser = nullableOption types.bool "Load skills from ~/.claude/skills.";
        skillsEnableClaudeProject = nullableOption types.bool "Load skills from .claude/skills.";
        skillsEnableCodexUser = nullableOption types.bool "Load skills from ~/.codex/skills.";
        skillsEnablePiUser = nullableOption types.bool "Load skills from ~/.pi/skills.";
        skillsEnablePiProject = nullableOption types.bool "Load skills from .pi/skills.";
        commandsEnableClaudeUser = nullableOption types.bool "Load commands from ~/.claude/commands.";
        commandsEnableClaudeProject = nullableOption types.bool "Load commands from .claude/commands.";
        commandsEnableOpencodeUser = nullableOption types.bool "Load commands from ~/.config/opencode/commands.";
        commandsEnableOpencodeProject = nullableOption types.bool "Load commands from .opencode/commands.";
        worktreeBase = nullableOption types.str "Base directory for agent-managed worktrees.";
        workspaceAdditionalDirectories = nullableOption stringList "Extra workspace roots.";
      };
      default = { };
      description = "Modes, subagents, isolation, commands, and skill discovery.";
    };

    providers = mkOption {
      type = settingGroup {
        disabled = nullableOption stringList "Disabled provider IDs.";
        webSearch = nullableOption types.str "Preferred web-search provider (legacy).";
        webSearchOrder = nullableOption stringList "Prioritized web search providers.";
        webSearchExclude = nullableOption stringList "Excluded web search providers.";
        webSearchTimeoutSeconds = nullableOption types.int "Web search provider timeout.";
        webSearchGeminiModel = nullableOption types.str "Gemini model ID for Google Search grounding.";
        exaEnabled = nullableOption types.bool "Enable Exa web search provider.";
        exaSearchDelayMs = nullableOption types.int "Exa minimum search delay in ms.";
        image = nullableOption types.str "Preferred image provider (legacy).";
        imageOrder = nullableOption stringList "Prioritized image generation providers.";
        antigravityEndpoint = enumOption [
          "auto"
          "chat"
          "discovery"
        ] "Antigravity endpoint routing strategy.";
        fireworksTier = enumOption [
          "standard"
          "priority"
        ] "Fireworks serving tier.";
        cacheRetention = enumOption [
          "auto"
          "long"
          "standard"
        ] "Prompt cache retention.";
        maxInFlightRequests = nullableOption (types.attrsOf types.int) "Max concurrent requests per provider.";
        anthropicServerSideFallback = nullableOption types.bool "Retry blocked Claude requests on Opus 4.8.";
        openaiCodexCodeMode = enumOption [
          "off"
          "auto"
          "on"
        ] "Codex code mode execution surface.";
        openaiCodexCodeModeDirectTools = nullableOption stringList "Direct tools for Codex code mode.";
        ollamaCloudMaxConcurrency = nullableOption types.int "Max concurrent Ollama Cloud subagents.";
        tinyModel = nullableOption types.str "Tiny model selector.";
        tinyModelDevice = nullableOption types.str "Tiny model device.";
        tinyModelDtype = nullableOption types.str "Tiny model data type.";
        memoryModel = nullableOption types.str "Memory model selector.";
        autoThinkingModel = nullableOption types.str "Automatic thinking classifier model.";
        autoThinkingMaxEffort = enumOption [
          "max"
          "xhigh"
          "high"
          "medium"
          "low"
          "minimal"
        ] "Maximum effort resolved by auto thinking classifier.";
        unexpectedStopModel = nullableOption types.str "Classifier for unexpected stop detection.";
        kimiApiFormat = nullableOption types.str "Kimi API format.";
        openaiWebsockets = enumOption [
          "auto"
          "on"
          "off"
        ] "Websocket policy for OpenAI Codex models.";
        openrouterVariant = nullableOption types.str "OpenRouter provider variant.";
        fetch = nullableOption types.str "Preferred fetch service.";
        appendOnlyContext = enumOption [
          "auto"
          "on"
          "off"
        ] "Use append-only provider context.";
        secretsEnabled = nullableOption types.bool "Enable secret redaction.";
        redactSecrets = nullableOption types.bool "Redact secrets from shared sessions.";
        shareServerUrl = nullableOption types.str "Share viewer base URL.";
        shareStore = enumOption [
          "blob"
          "s3"
        ] "Share encrypted session storage target.";
        codexResetsAutoRedeem = enumOption [
          "unset"
          "yes"
          "no"
        ] "Auto-redeem saved Codex resets.";
        codexResetsMinBlockedMinutes = nullableOption types.int "Min blocked minutes before auto-redeem.";
        codexResetsKeepCredits = nullableOption types.int "Reserved credit ceiling for auto-redeem.";
        codexResetsSalvageHorizonHours = nullableOption types.int "Salvage horizon in hours for expiring credits.";
        ttsLocalModel = enumOption [ "kokoro" ] "Local TTS model.";
        ttsLocalVoice = nullableOption types.str "Local TTS voice.";
        speechEnabled = nullableOption types.bool "Speak assistant output aloud.";
        speechEnhanced = nullableOption types.bool "Rewrite assistant output to spoken prose.";
        speechMode = enumOption [
          "assistant"
          "all"
          "yield"
        ] "What to speak aloud.";
        speechVoice = nullableOption types.str "Spoken voice name.";
        sttEnabled = nullableOption types.bool "Enable microphone speech-to-text.";
        sttLanguage = nullableOption types.str "Speech-to-text language.";
        sttModelName = enumOption [
          "parakeet"
          "whisper-base"
          "whisper-small"
          "whisper-large-v3-turbo"
        ] "Speech-to-text model.";
        sttSubmitTrigger = enumOption [
          "never"
          "release"
          "sentence"
          "submit"
        ] "Speech submission trigger.";
        recapEnabled = nullableOption types.bool "Generate idle recaps.";
        recapIdleSeconds = nullableOption types.int "Idle seconds before recap.";
        collabDisplayName = nullableOption types.str "Collab participant display name.";
        collabRelayUrl = nullableOption types.str "Collab relay URL.";
        collabWebUrl = nullableOption types.str "Collab browser web URL.";
        devAutoqa = nullableOption types.bool "Automated tool issue reporting.";
        devAutoqaConsent = enumOption [
          "unset"
          "granted"
          "denied"
        ] "Auto-QA reporting consent.";
        devAutoqaPushEndpoint = nullableOption types.str "Auto-QA push endpoint.";
        devAutoqaPushToken = nullableOption types.str "Auto-QA push token.";
        thinkingBudgets = nullableOption json.type "Per-effort thinking token budgets.";
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
        message = lib.concatStringsSep "
" providerValidationErrors;
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
