{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption optionalAttrs;
  types = lib.types;
  cfg = config.claudeCode;

  nullableSetting =
    description:
    mkOption {
      type = types.nullOr types.anything;
      default = null;
      inherit description;
    };

  # These are settings.json keys. Claude's separate ~/.claude.json globals and
  # session-only ultracode are intentionally not serialized here.
  configuredSettings = lib.filterAttrs (_: value: value != null) {
    advisorModel = cfg.advisorModel;
    agent = cfg.agent;
    allowAllClaudeAiMcps = cfg.allowAllClaudeAiMcps;
    allowedChannelPlugins = cfg.allowedChannelPlugins;
    allowedHttpHookUrls = cfg.allowedHttpHookUrls;
    allowedMcpServers = cfg.allowedMcpServers;
    allowManagedHooksOnly = cfg.allowManagedHooksOnly;
    allowManagedMcpServersOnly = cfg.allowManagedMcpServersOnly;
    allowManagedPermissionRulesOnly = cfg.allowManagedPermissionRulesOnly;
    alwaysThinkingEnabled = cfg.alwaysThinkingEnabled;
    apiKeyHelper = cfg.apiKeyHelper;
    attribution = cfg.attribution;
    autoMemoryDirectory = cfg.autoMemoryDirectory;
    autoMemoryEnabled = cfg.autoMemoryEnabled;
    autoMode = cfg.autoMode;
    autoScrollEnabled = cfg.autoScrollEnabled;
    autoUpdatesChannel = cfg.autoUpdatesChannel;
    availableModels = cfg.availableModels;
    awaySummaryEnabled = cfg.awaySummaryEnabled;
    awsAuthRefresh = cfg.awsAuthRefresh;
    awsCredentialExport = cfg.awsCredentialExport;
    blockedMarketplaces = cfg.blockedMarketplaces;
    channelsEnabled = cfg.channelsEnabled;
    claudeMd = cfg.claudeMd;
    claudeMdExcludes = cfg.claudeMdExcludes;
    cleanupPeriodDays = cfg.cleanupPeriodDays;
    companyAnnouncements = cfg.companyAnnouncements;
    defaultShell = cfg.defaultShell;
    deniedMcpServers = cfg.deniedMcpServers;
    disableAgentView = cfg.disableAgentView;
    disableAllHooks = cfg.disableAllHooks;
    disableAutoMode = cfg.disableAutoMode;
    disableBundledSkills = cfg.disableBundledSkills;
    disableDeepLinkRegistration = cfg.disableDeepLinkRegistration;
    disabledMcpjsonServers = cfg.disabledMcpjsonServers;
    disableRemoteControl = cfg.disableRemoteControl;
    disableSkillShellExecution = cfg.disableSkillShellExecution;
    disableWorkflows = cfg.disableWorkflows;
    editorMode = cfg.editorMode;
    effortLevel = cfg.effortLevel;
    enableAllProjectMcpServers = cfg.enableAllProjectMcpServers;
    enabledMcpjsonServers = cfg.enabledMcpjsonServers;
    enabledPlugins = cfg.enabledPlugins;
    extraKnownMarketplaces = cfg.extraKnownMarketplaces;
    fallbackModel = cfg.fallbackModel;
    fastModePerSessionOptIn = cfg.fastModePerSessionOptIn;
    feedbackSurveyRate = cfg.feedbackSurveyRate;
    fileSuggestion = cfg.fileSuggestion;
    forceLoginMethod = cfg.forceLoginMethod;
    forceLoginOrgUUID = cfg.forceLoginOrgUUID;
    forceRemoteSettingsRefresh = cfg.forceRemoteSettingsRefresh;
    gcpAuthRefresh = cfg.gcpAuthRefresh;
    hooks = cfg.hooks;
    httpHookAllowedEnvVars = cfg.httpHookAllowedEnvVars;
    includeCoAuthoredBy = cfg.includeCoAuthoredBy;
    includeGitInstructions = cfg.includeGitInstructions;
    language = cfg.language;
    maxSkillDescriptionChars = cfg.maxSkillDescriptionChars;
    minimumVersion = cfg.minimumVersion;
    modelOverrides = cfg.modelOverrides;
    otelHeadersHelper = cfg.otelHeadersHelper;
    outputStyle = cfg.outputStyle;
    parentSettingsBehavior = cfg.parentSettingsBehavior;
    permissions = cfg.permissions;
    plansDirectory = cfg.plansDirectory;
    pluginSuggestionMarketplaces = cfg.pluginSuggestionMarketplaces;
    pluginTrustMessage = cfg.pluginTrustMessage;
    policyHelper = cfg.policyHelper;
    preferredNotifChannel = cfg.preferredNotifChannel;
    prefersReducedMotion = cfg.prefersReducedMotion;
    prUrlTemplate = cfg.prUrlTemplate;
    requiredMaximumVersion = cfg.requiredMaximumVersion;
    requiredMinimumVersion = cfg.requiredMinimumVersion;
    respectGitignore = cfg.respectGitignore;
    sandbox = cfg.sandbox;
    showClearContextOnPlanAccept = cfg.showClearContextOnPlanAccept;
    showThinkingSummaries = cfg.showThinkingSummaries;
    showTurnDuration = cfg.showTurnDuration;
    skillListingBudgetFraction = cfg.skillListingBudgetFraction;
    skillOverrides = cfg.skillOverrides;
    skipWebFetchPreflight = cfg.skipWebFetchPreflight;
    spinnerTipsEnabled = cfg.spinnerTipsEnabled;
    spinnerTipsOverride = cfg.spinnerTipsOverride;
    spinnerVerbs = cfg.spinnerVerbs;
    sshConfigs = cfg.sshConfigs;
    strictKnownMarketplaces = cfg.strictKnownMarketplaces;
    strictPluginOnlyCustomization = cfg.strictPluginOnlyCustomization;
    syntaxHighlightingDisabled = cfg.syntaxHighlightingDisabled;
    teammateMode = cfg.teammateMode;
    terminalProgressBarEnabled = cfg.terminalProgressBarEnabled;
    tui = cfg.tui;
    useAutoModeDuringPlan = cfg.useAutoModeDuringPlan;
    viewMode = cfg.viewMode;
    voice = cfg.voice;
    voiceEnabled = cfg.voiceEnabled;
    workflowKeywordTriggerEnabled = cfg.workflowKeywordTriggerEnabled;
    worktree = cfg.worktree;
    wslInheritsWindowsSettings = cfg.wslInheritsWindowsSettings;
  };

  statusLineSettings = lib.filterAttrs (_: value: value != null) (
    {
      type = cfg.statusLine.type;
      command = cfg.statusLine.command;
    }
    // cfg.statusLine.extraSettings
  );
in
{
  options.claudeCode = {
    enable = mkEnableOption "claude-code";

    statusLine = {
      enable = mkEnableOption "custom statusLine";

      type = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Status line renderer type.";
      };

      command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Command used by a command status line.";
      };

      extraSettings = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Additional raw statusLine fields.";
      };
    };

    auth = mkOption {
      type = types.submodule {
        options = {
          type = mkOption {
            type = types.enum [ "none" "oauth" "apiKey" ];
            default = "none";
            description = "Authentication type: none (passthrough), oauth (token-based), or apiKey (API key-based).";
          };

          secret = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "The sops placeholder for the authentication secret. Required when type is oauth or apiKey.";
          };
        };
      };
      default = { };
      description = "Authentication configuration for Claude Code.";
    };

    baseUrl = mkOption {
      type = types.str;
      default = "https://api.anthropic.com";
      description = "Base URL for the Anthropic API.";
    };

    model = mkOption {
      type = types.str;
      default = "opus";
      description = "Default model to use (opus, sonnet, haiku, or a specific model ID).";
    };

    timeoutMs = mkOption {
      type = types.int;
      default = 120000;
      description = "API timeout in milliseconds.";
    };

    env = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Environment variables written to Claude Code settings.json.";
    };

    extraEnv = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Additional environment variables merged into the Claude Code settings.";
    };

    advisorModel = nullableSetting "Model for the server-side advisor tool.";
    agent = nullableSetting "Named subagent to run as the main thread.";
    allowAllClaudeAiMcps = nullableSetting "Allow claude.ai connectors alongside managed MCP configuration.";
    allowedChannelPlugins = nullableSetting "Managed allowlist of channel plugins.";
    allowedHttpHookUrls = nullableSetting "Allowlist of URL patterns that HTTP hooks may target.";
    allowedMcpServers = nullableSetting "Managed allowlist of MCP servers.";
    allowManagedHooksOnly = nullableSetting "Load only managed, SDK, and force-enabled plugin hooks.";
    allowManagedMcpServersOnly = nullableSetting "Respect only managed allowedMcpServers entries.";
    allowManagedPermissionRulesOnly = nullableSetting "Use only managed allow, ask, and deny permission rules.";
    alwaysThinkingEnabled = nullableSetting "Enable extended thinking by default.";
    apiKeyHelper = nullableSetting "Script that generates API credentials.";
    attribution = nullableSetting "Customize commit and pull request attribution.";
    autoMemoryDirectory = nullableSetting "Directory used for auto memory storage.";
    autoMemoryEnabled = nullableSetting "Enable auto memory.";
    autoMode = nullableSetting "Customize auto mode classifier rules.";
    autoScrollEnabled = nullableSetting "Follow new output in fullscreen mode.";
    autoUpdatesChannel = nullableSetting "Claude Code update channel.";
    availableModels = nullableSetting "Restrict models selectable through Claude Code.";
    awaySummaryEnabled = nullableSetting "Show a recap after returning to the terminal.";
    awsAuthRefresh = nullableSetting "Script that refreshes AWS authentication.";
    awsCredentialExport = nullableSetting "Script that outputs AWS credentials JSON.";
    blockedMarketplaces = nullableSetting "Managed blocklist of plugin marketplace sources.";
    channelsEnabled = nullableSetting "Enable channels.";
    claudeMd = nullableSetting "Managed CLAUDE.md-style instructions.";
    claudeMdExcludes = nullableSetting "CLAUDE.md paths to exclude from memory loading.";
    cleanupPeriodDays = nullableSetting "Age in days before old session files are removed.";
    companyAnnouncements = nullableSetting "Startup announcements.";
    defaultShell = nullableSetting "Default shell for input-box commands.";
    deniedMcpServers = nullableSetting "Managed denylist of MCP servers.";
    disableAgentView = nullableSetting "Disable background agents and agent view.";
    disableAllHooks = nullableSetting "Disable all hooks and custom status lines.";
    disableAutoMode = nullableSetting "Disable auto mode.";
    disableBundledSkills = nullableSetting "Disable bundled skills and workflows.";
    disableDeepLinkRegistration = nullableSetting "Disable claude-cli protocol handler registration.";
    disabledMcpjsonServers = nullableSetting "Project MCP servers to reject.";
    disableRemoteControl = nullableSetting "Disable remote control.";
    disableSkillShellExecution = nullableSetting "Disable shell execution from custom skills and commands.";
    disableWorkflows = nullableSetting "Disable dynamic workflows.";
    editorMode = nullableSetting "Input prompt key binding mode.";
    effortLevel = nullableSetting "Persisted effort level.";
    enableAllProjectMcpServers = nullableSetting "Automatically approve all project MCP servers.";
    enabledMcpjsonServers = nullableSetting "Project MCP servers to approve.";
    enabledPlugins = nullableSetting "Plugin enablement map.";
    extraKnownMarketplaces = nullableSetting "Additional plugin marketplaces.";
    fallbackModel = nullableSetting "Fallback model chain.";
    fastModePerSessionOptIn = nullableSetting "Require fast mode opt-in for every session.";
    feedbackSurveyRate = nullableSetting "Session quality survey probability.";
    fileSuggestion = nullableSetting "Custom file suggestion command.";
    forceLoginMethod = nullableSetting "Restrict login to Claude.ai or Console accounts.";
    forceLoginOrgUUID = nullableSetting "Require login from one or more organization UUIDs.";
    forceRemoteSettingsRefresh = nullableSetting "Require fresh remote managed settings before startup.";
    gcpAuthRefresh = nullableSetting "Script that refreshes GCP credentials.";
    hooks = nullableSetting "Hook configuration.";
    httpHookAllowedEnvVars = nullableSetting "Environment variables HTTP hooks may interpolate.";
    includeCoAuthoredBy = nullableSetting "Deprecated attribution toggle.";
    includeGitInstructions = nullableSetting "Include built-in git workflow instructions.";
    language = nullableSetting "Preferred response and voice dictation language.";
    maxSkillDescriptionChars = nullableSetting "Per-skill description character limit.";
    minimumVersion = nullableSetting "Minimum version used by auto-update.";
    modelOverrides = nullableSetting "Provider-specific model ID overrides.";
    otelHeadersHelper = nullableSetting "Script that generates OpenTelemetry headers.";
    outputStyle = nullableSetting "Output style.";
    parentSettingsBehavior = nullableSetting "Managed parent settings merge behavior.";
    permissions = nullableSetting "Permission settings.";
    plansDirectory = nullableSetting "Directory for plan files.";
    pluginSuggestionMarketplaces = nullableSetting "Managed marketplaces allowed to provide plugin suggestions.";
    pluginTrustMessage = nullableSetting "Managed plugin trust warning message.";
    policyHelper = nullableSetting "Managed policy helper configuration.";
    preferredNotifChannel = nullableSetting "Task-complete and permission-prompt notification method.";
    prefersReducedMotion = nullableSetting "Reduce UI animation.";
    prUrlTemplate = nullableSetting "Template for pull request URLs.";
    requiredMaximumVersion = nullableSetting "Managed maximum Claude Code version.";
    requiredMinimumVersion = nullableSetting "Managed minimum Claude Code version.";
    respectGitignore = nullableSetting "Respect .gitignore in file suggestions.";
    sandbox = nullableSetting "Sandbox configuration.";
    showClearContextOnPlanAccept = nullableSetting "Show clear-context on plan acceptance.";
    showThinkingSummaries = nullableSetting "Show thinking summaries.";
    showTurnDuration = nullableSetting "Show response duration.";
    skillListingBudgetFraction = nullableSetting "Context fraction reserved for skill listings.";
    skillOverrides = nullableSetting "Per-skill visibility overrides.";
    skipWebFetchPreflight = nullableSetting "Skip WebFetch domain safety preflight.";
    spinnerTipsEnabled = nullableSetting "Show spinner tips.";
    spinnerTipsOverride = nullableSetting "Custom spinner tips.";
    spinnerVerbs = nullableSetting "Custom spinner verbs.";
    sshConfigs = nullableSetting "Desktop SSH connection list.";
    strictKnownMarketplaces = nullableSetting "Managed marketplace allowlist.";
    strictPluginOnlyCustomization = nullableSetting "Managed plugin-only customization policy.";
    syntaxHighlightingDisabled = nullableSetting "Disable syntax highlighting.";
    teammateMode = nullableSetting "Agent team display mode.";
    terminalProgressBarEnabled = nullableSetting "Show terminal progress bar.";
    tui = nullableSetting "Terminal UI renderer.";
    useAutoModeDuringPlan = nullableSetting "Use auto mode semantics during planning.";
    viewMode = nullableSetting "Default transcript view mode.";
    voice = nullableSetting "Voice dictation settings.";
    voiceEnabled = nullableSetting "Legacy voice.enabled alias.";
    workflowKeywordTriggerEnabled = nullableSetting "Enable the ultracode workflow keyword trigger.";
    worktree = nullableSetting "Worktree configuration.";
    wslInheritsWindowsSettings = nullableSetting "Read Windows managed settings from WSL.";

    extraSettings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Additional raw Claude Code settings merged after typed settings.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = (cfg.auth.type == "none") || (cfg.auth.secret != null);
        message = "claudeCode.auth.secret must be set when auth.type is '${cfg.auth.type}'";
      }
    ];

    home.file = mkIf cfg.statusLine.enable {
      ".claude/claude-statusline.sh" = {
        source = ./claude-statusline.sh;
        executable = true;
      };
    };

    sops.templates."claude-settings".content = builtins.toJSON (
      configuredSettings
      // cfg.extraSettings
      // {
        env = {
          ANTHROPIC_BASE_URL = cfg.baseUrl;
          API_TIMEOUT_MS = toString cfg.timeoutMs;
        }
        // cfg.env
        // (optionalAttrs (cfg.auth.type == "oauth") {
          ANTHROPIC_AUTH_TOKEN = cfg.auth.secret;
        })
        // (optionalAttrs (cfg.auth.type == "apiKey") {
          ANTHROPIC_API_KEY = cfg.auth.secret;
        })
        // cfg.extraEnv;
        model = cfg.model;
      }
      // optionalAttrs (cfg.statusLine.enable || statusLineSettings != { }) {
        statusLine =
          if cfg.statusLine.enable then
            {
              type = "command";
              command = "${config.home.homeDirectory}/.claude/claude-statusline.sh";
            }
          else
            statusLineSettings;
      }
    );
    sops.templates."claude-settings".path = "${config.home.homeDirectory}/.claude/settings.json";
  };
}
