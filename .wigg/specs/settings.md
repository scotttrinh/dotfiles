# Settings Management

How tool configuration files are managed declaratively in Nix.

## Settings vs Secrets

This repository distinguishes between two types of configuration:

| Aspect | Secrets | Settings |
|--------|---------|----------|
| **Sensitivity** | Confidential (API keys, tokens) | Not sensitive (preferences, feature flags) |
| **Storage** | Encrypted in `secrets.yaml` | Plain text in Nix config |
| **Version control** | Encrypted values only | Fully readable |
| **Injection method** | sops-nix decryption at runtime | Generated at build time |
| **Examples** | `ANTHROPIC_API_KEY`, `CLAUDE_CODE_AUTH_TOKEN` | Model selection, timeouts, UI preferences |

**Key insight from nooks**: In the nooks module, settings are copied (read-write) while secrets are bind-mounted (read-only). For dotfiles, both are managed via home-manager, but the conceptual distinction remains important.

## The Pattern: Option-Driven Configuration

Tool settings are defined as Nix options in modules, allowing:
- Type-safe configuration
- Machine-specific overrides
- Declarative generation of config files

### Example: Claude Code Module

The `modules/home/claude-code/` module demonstrates this pattern:

```nix
# 1. Define options in the module
options.claudeCode = {
  enable = lib.mkEnableOption "claude-code";

  model = lib.mkOption {
    type = lib.types.str;
    default = "opus";
    description = "Default model to use";
  };

  baseUrl = lib.mkOption {
    type = lib.types.str;
    default = "https://api.anthropic.com";
    description = "Base URL for the Anthropic API";
  };

  auth = lib.mkOption {
    type = lib.types.submodule { ... };
    description = "Authentication configuration";
  };
};

# 2. Generate config file from options
config = lib.mkIf cfg.enable {
  sops.templates."claude-settings".content = builtins.toJSON {
    env = {
      ANTHROPIC_BASE_URL = cfg.baseUrl;
    };
    model = cfg.model;
  };
  sops.templates."claude-settings".path =
    "${config.home.homeDirectory}/.claude/settings.json";
};
```

```nix
# 3. Set values in machine config
# configurations/darwin/triangle.nix
home-manager.users.scotttrinh = {
  claudeCode = {
    enable = true;
    model = "opus";
    baseUrl = "https://ai-gateway.vercel.sh";
    auth = {
      type = "oauth";
      secret = config.sops.placeholder.claude_code_auth_token;
    };
  };
};
```

## Why Use sops.templates for Settings?

Even though settings aren't sensitive, we use `sops.templates` because:

1. **Secrets can be embedded**: Auth tokens go in the same file as model preferences
2. **Single source of truth**: One file for all Claude Code config
3. **Runtime generation**: Secrets are substituted when the template is rendered

For purely non-sensitive settings (no secrets), you could use `home.file` instead:

```nix
# Alternative for config without secrets
home.file.".config/tool/settings.json".text = builtins.toJSON {
  theme = "dark";
  fontSize = 14;
};
```

## Per-Machine Settings

Settings can vary per machine using home-manager overrides:

```nix
# configurations/darwin/triangle.nix (work machine)
home-manager.users.scotttrinh = {
  claudeCode = {
    model = "opus";
    baseUrl = "https://ai-gateway.vercel.sh";  # Vercel's gateway
    auth.type = "oauth";
  };
};

# configurations/darwin/frannie.nix (personal machine)
home-manager.users.scotttrinh = {
  claudeCode = {
    model = "opus";
    baseUrl = "https://api.z.ai/api/anthropic";  # z.ai proxy
    auth.type = "apiKey";
  };
};
```

## Common Settings Patterns

### Pattern 1: Inline JSON Generation

Use `builtins.toJSON` to generate JSON from Nix:

```nix
home.file.".config/tool/config.json".text = builtins.toJSON {
  version = 1;
  features = {
    streaming = true;
    caching = true;
  };
  paths = {
    workspace = "${config.home.homeDirectory}/workspace";
  };
};
```

### Pattern 2: TOML/YAML Generation

Use format libraries from nixpkgs:

```nix
{ pkgs, ... }:

let
  tomlFormat = pkgs.formats.toml { };
in {
  home.file.".config/tool/config.toml".source = tomlFormat.generate "config.toml" {
    core.workspace = "~/workspace";
    agent.model = "claude-sonnet-4-20250514";
  };
}
```

### Pattern 3: Template Files with Secrets

Use `sops.templates` when secrets must be embedded:

```nix
sops.templates."tool-config" = {
  content = builtins.toJSON {
    apiKey = config.sops.placeholder.tool_api_key;  # Secret
    timeout = 30000;                                  # Setting
  };
  path = "${config.home.homeDirectory}/.config/tool/config.json";
};
```

### Pattern 4: External Source Files

Reference files from the repo for complex configs:

```nix
home.file.".config/tool/rules.yaml".source = ./configs/tool-rules.yaml;
```

## XDG Base Directories

Most tools expect config in XDG-standard locations:

| XDG Variable | Default Path | Example Use |
|--------------|--------------|-------------|
| `$XDG_CONFIG_HOME` | `~/.config` | Claude settings, git config |
| `$XDG_DATA_HOME` | `~/.local/share` | Tool data, databases |
| `$XDG_STATE_HOME` | `~/.local/state` | Logs, history |

Home-manager sets these automatically. Reference them via:

```nix
"${config.xdg.configHome}/tool/config.json"
# Expands to: ~/.config/tool/config.json
```

## Adding a New Tool's Settings

1. **Create a module** in `modules/home/`:

```nix
# modules/home/mytool.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.myTool;
in {
  options.myTool = {
    enable = lib.mkEnableOption "MyTool";

    workspace = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/workspace";
    };

    features = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    home.file.".config/mytool/config.json".text = builtins.toJSON {
      workspace = cfg.workspace;
      features = cfg.features;
    };
  };
}
```

2. **Enable in user config** (`configurations/home/scotttrinh.nix`):

```nix
myTool = {
  enable = true;
  features.autoSave = true;
};
```

3. **Override per machine** if needed:

```nix
# configurations/darwin/triangle.nix
home-manager.users.scotttrinh = {
  myTool.workspace = "${config.home.homeDirectory}/work";
};
```

## Relationship to Nooks

When running inside a nook container (via the nooks module on NixOS), settings work differently:

- **Host (this dotfiles repo)**: Settings generated via home-manager, secrets via sops-nix
- **Nook containers**: Settings copied in at container start, secrets bind-mounted read-only

The nooks module has its own `services.nook.settings.files` option for injecting config into containers. See the [nooks documentation](https://github.com/scotttrinh/nook) for details.

## See Also

- [secrets.md](./secrets.md) - For sensitive credentials (API keys, tokens)
- [modules.md](./modules.md) - Module structure and conventions
- [machines.md](./machines.md) - Per-machine configuration
