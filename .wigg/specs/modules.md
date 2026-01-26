# Module Structure and Conventions

## Module Organization

### Home Manager Modules (`modules/home/`)

All `.nix` files in this directory are auto-imported via `modules/home/default.nix`:

```nix
imports = builtins.map (fn: ./${fn})
  (builtins.filter (fn: fn != "default.nix")
    (builtins.attrNames (builtins.readDir ./.)));
```

#### Core Infrastructure
- **me.nix** - User identity options (`config.me.username`, `config.me.fullname`, `config.me.email`)
- **sops.nix** - SOPS defaults and age key location

#### Shell & Development
- **shell.nix** - Zsh, Starship prompt, Zoxide, shell aliases
- **git.nix** - Git configuration using `config.me.*`
- **direnv.nix** - nix-direnv integration
- **nix-index.nix** - Command-not-found database

#### System & Packages
- **packages.nix** - Common packages (Node.js, Python, Rust, CLI tools)
- **emacs.nix** - Emacs with vterm and treesitter
- **gc.nix** - Automatic Nix garbage collection
- **nix.nix** - Nix configuration

#### Custom Tool Modules
Subdirectories with their own `default.nix`:
- **claude-code/** - Claude Code configuration with auth options (see [settings.md](./settings.md) for details)
- **aerospace/** - macOS window manager
- **gemini-cli/** - Gemini CLI setup
- **opencode/** - OpenCode tool setup

The claude-code module is the canonical example of option-driven settings generation. It defines typed options (`model`, `baseUrl`, `auth`, `timeoutMs`) and generates `~/.claude/settings.json` using `sops.templates`.

### Darwin Modules (`modules/darwin/`)

- **default.nix** - System-wide macOS configurations:
  - Dock: autohide, left orientation, 32px icons
  - Finder: show extensions, POSIX paths, status bar
  - Keyboard: CapsLock→Ctrl remapping
  - Trackpad: click settings
  - Security: TouchID for sudo
  - Homebrew: base casks and brews

### NixOS Modules (`modules/nixos/`)

#### common/default.nix
- Dynamically creates user accounts from `configurations/home/`
- Sets up Nix cache trust settings
- Shared between Darwin and NixOS

#### orbstack.nix
OrbStack-specific settings for NixOS VMs:
- Shell init for OrbStack CLI tools (`/opt/orbstack-guest/etc/profile-*`)
- DNS configuration (use OrbStack's resolv.conf)
- Disable host sshd (use OrbStack's SSH)
- systemd watchdog adjustments for container environment
- SSH config include for OrbStack tools
- Extra platforms for emulation (x86_64-linux on Apple Silicon)
- OrbStack group (gid 67278)

**Usage:**
```nix
imports = [ self.nixosModules.orbstack ];
```

### Flake Modules (`modules/flake/`)

- **toplevel.nix** - nixos-unified integration and perSystem config

## Common Patterns

### Pattern 1: Option-driven Configuration

Define options in modules, set values in configurations:

```nix
# modules/home/me.nix defines:
options.me = {
  username = lib.mkOption { type = lib.types.str; };
  fullname = lib.mkOption { type = lib.types.str; };
  email = lib.mkOption { type = lib.types.str; };
};

# configurations/home/scotttrinh.nix sets:
me = {
  username = "scotttrinh";
  fullname = "Scott Trinh";
  email = "scott@scotttrinh.com";
};

# modules/home/git.nix uses:
programs.git.userName = config.me.fullname;
```

### Pattern 2: Flake Inheritance

All configs inherit from `self.{darwinModules,homeModules}.default`:

```nix
# In configurations/darwin/<hostname>.nix:
imports = [ self.darwinModules.default ];

# In configurations/home/<username>.nix:
imports = [ self.homeModules.default ];
```

### Pattern 3: Per-Machine Overrides

Machine-specific config in `home-manager.users.<username>`:

```nix
# In configurations/darwin/triangle.nix:
home-manager.users.scotttrinh = {
  home.packages = with pkgs; [ git-lfs gh ];
  claudeCode = {
    authType = "oauth";
    baseUrl = "https://custom-gateway.example.com";
  };
};
```

### Pattern 4: Activation Scripts

Use home-manager DAG for ordered setup:

```nix
home.activation.cloneWorkRepos = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  echo "Setting up work repositories..."
  # Clone and setup repos
'';
```

### Pattern 5: Module Enable Flags

Custom modules use enable options:

```nix
# In module:
options.claudeCode.enable = lib.mkEnableOption "Claude Code";
config = lib.mkIf config.claudeCode.enable { ... };

# In config:
claudeCode.enable = true;
```

## Adding a New Module

1. Create `modules/home/mymodule.nix` (or `modules/home/mymodule/default.nix` for complex modules)
2. Define options if needed
3. Set `config` with the actual configuration
4. The module is automatically imported via the auto-import pattern

Example minimal module:

```nix
{ config, lib, pkgs, ... }:

{
  options.myModule.enable = lib.mkEnableOption "My Module";

  config = lib.mkIf config.myModule.enable {
    home.packages = [ pkgs.some-package ];
  };
}
```
