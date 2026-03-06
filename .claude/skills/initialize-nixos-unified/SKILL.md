---
name: nix-dotfiles
description: Guides a developer through building their own nixos-unified dotfiles repository from scratch, using this repo as a reference architecture. Use when someone wants to set up Nix-based system configuration or dotfiles management.
---

# Build Your Own Nix Dotfiles

> An interactive skill that guides you through building a nixos-unified dotfiles repository from scratch, using this repo as a reference architecture.

## Environment Discovery

The following was detected automatically:

```
!`${CLAUDE_SKILL_DIR}/scripts/discover.sh`
```

## Instructions

You are guiding a developer through creating their own Nix-based dotfiles from scratch. This repo (scotttrinh/dotfiles) is the reference — the user is NOT forking it, they are building their own.

Work through the phases below **in order**. Each phase is interactive: ask questions, run discovery commands, and generate files incrementally. Do not dump everything at once.

Use the discovery output above to pre-fill values and suggest sensible defaults throughout.

### Phase 1: Confirm Discovery

Summarize the detected environment to the user. Confirm:
- OS and architecture
- Whether Nix is installed (if not, guide them to install it first via the Determinate installer)
- Username and hostname (these become file names in the config)
- What tools are already installed (to suggest modules later)

### Phase 2: Identity Setup

Ask the user for:

1. **Full name** — for git commits (e.g., "Jane Smith")
2. **Email** — for git config (e.g., "jane@example.com")
3. **GitHub username** — for the repository name

Store these for use in generated Nix code.

### Phase 3: Bootstrap from Template

Use the official nixos-unified template to scaffold the repo. Pick the template based on the detected OS:

- **macOS** (Darwin): `macos`
- **Linux** (NixOS): `linux`
- **Home-manager only** (no system config): `home`

Run the bootstrap script:

```bash
${CLAUDE_SKILL_DIR}/scripts/bootstrap.sh <template> <output-dir>
```

For example: `${CLAUDE_SKILL_DIR}/scripts/bootstrap.sh macos ~/dotfiles`

After bootstrapping, the template provides the standard nixos-unified structure. Walk the user through the generated files and customize them:

1. **`configurations/home/<username>.nix`** — set `me.username`, `me.fullname`, `me.email` from Phase 2
2. **`configurations/darwin/<hostname>.nix`** (or `nixos/`) — set `nixpkgs.hostPlatform`, `networking.hostName`, `system.primaryUser`
3. **`modules/home/`** — review what the template provides, then enhance with modules from Phase 4

See [templates.md](templates.md) for reference versions of each file if the template needs adjustment.

Have the user run `nix run .#activate` to verify the base config works before adding modules.

### Phase 4: Incremental Module Interview

After the minimal config is working, walk through each category below **one at a time**. For each:

1. Ask if the user wants it
2. If yes, generate the module file(s)
3. Explain what the module does
4. Have them activate and verify

Use discovery results to suggest sensible defaults (e.g., if ghostty is installed, suggest configuring it).

#### Category: Packages

Common development packages. Ask what languages and tools they use.

```nix
# modules/home/packages.nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ripgrep
    fd
    tree
    jq
    less
  ];

  programs = {
    bat.enable = true;
    fzf.enable = true;
    jq.enable = true;
    btop.enable = true;
  };
}
```

Extend `home.packages` based on what the user needs:
- **Node.js**: `nodejs_24 corepack_24`
- **Python**: `python312 uv`
- **Rust**: add `rust-overlay` input, then `rust-bin.stable.latest.default`
- **Go**: `go`

#### Category: Direnv

Automatic environment loading for Nix projects. Strongly recommend this for any Nix user.

```nix
# modules/home/direnv.nix
{ ... }:
{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    config.global.hide_env_diff = true;
  };
}
```

#### Category: Editor

Ask which editor they use. Only generate the module for their choice.

**Emacs:**

```nix
# modules/home/emacs.nix
{ pkgs, ... }:
{
  programs.emacs = {
    enable = true;
    extraPackages = epkgs: with epkgs; [
      vterm
      treesit-grammars.with-all-grammars
    ];
  };
}
```

**Neovim:**

```nix
# modules/home/neovim.nix
{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };
}
```

**VS Code / Cursor:** These are typically installed via Homebrew casks on macOS. Add to the darwin module's `homebrew.casks` list rather than a home-manager module.

#### Category: Terminal

Ask which terminal they use. Terminals on macOS are typically Homebrew casks.

**Ghostty** (recommended — already a cask in reference config):
Add `"ghostty"` to `homebrew.casks` in `modules/darwin/default.nix`. Configuration lives at `~/.config/ghostty/config` — optionally manage it via `home.file`.

**Kitty:**

```nix
# modules/home/kitty.nix
{ ... }:
{
  programs.kitty = {
    enable = true;
    settings = {
      font_size = 14;
      window_padding_width = 4;
    };
  };
}
```

#### Category: Window Manager (macOS only)

**AeroSpace** — tiling window manager. Uses a TOML config file.

```nix
# modules/home/aerospace/default.nix
{ ... }:
{
  home.file.".config/aerospace/aerospace.toml".source = ./aerospace.toml;
}
```

Create `modules/home/aerospace/aerospace.toml` with the user's preferred keybindings. The reference repo has a working config to draw from.

#### Category: Homebrew Extras (macOS only)

Ask what GUI apps they want managed via Homebrew. Add to `homebrew.casks` in the darwin module or the host-specific config.

Common casks: `"1password"`, `"slack"`, `"discord"`, `"raycast"`, `"orbstack"`, `"docker"`.

#### Category: AI/LLM Tools

Ask if they use any AI coding tools. For simple setups (no secrets), install via packages:

```nix
# Add to modules/home/packages.nix:
# First add the input to flake.nix:
#   llm-agents.url = "github:numtide/llm-agents.nix";
# Then in packages.nix:
home.packages = [
  flake.inputs.llm-agents.packages.${pkgs.system}.claude-code
];
```

For advanced setups with API keys and custom settings, follow the option-driven pattern from the reference repo's `modules/home/claude-code/` module.

#### Category: Secrets Management

Only offer this if the user has API keys or tokens to manage. Requires `sops-nix` and `age`.

1. Add inputs to `flake.nix`:

```nix
sops-nix.url = "github:Mic92/sops-nix";
sops-nix.inputs.nixpkgs.follows = "nixpkgs";
```

2. Create `modules/home/sops.nix`:

```nix
{ flake, config, ... }:
{
  imports = [ flake.inputs.sops-nix.homeManagerModules.sops ];
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
}
```

3. Generate an age key:

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

4. Create `.sops.yaml` with the public key and `secrets.yaml` with encrypted values.

Walk the user through each step — secrets management is the most error-prone part.

### Phase 5: Per-Machine Overrides

If the user has multiple machines (e.g., work + personal), show how to add machine-specific config. The pattern is:

```nix
# configurations/darwin/<hostname>.nix
home-manager.users.<username> = { lib, config, ... }: {
  # Machine-specific packages
  home.packages = with pkgs; [ git-lfs ];

  # Machine-specific option overrides
  someModule.someSetting = "override-value";
};
```

Create a new `configurations/darwin/<hostname>.nix` for each machine. The base user config in `configurations/home/<username>.nix` is shared across all machines.

### Phase 6: Verification

After all modules are set up:

1. Run `nix fmt` to format all Nix files
2. Run `nix flake check` to verify evaluation
3. Run `nix run .#activate` to apply the full configuration
4. Verify key programs are available: `which git`, `which zsh`, etc.
5. Suggest committing and pushing to GitHub

## Reference Patterns

These patterns from the reference repo should be followed when generating Nix code. For detailed templates, see [templates.md](templates.md).

### Auto-Import

Every `.nix` file (and subdirectory with `default.nix`) in `modules/home/` is automatically imported. No manual import list to maintain.

### Option-Driven Modules

For complex modules, define typed options and use `mkIf` for conditional config:

```nix
{ config, lib, ... }:
let cfg = config.myModule; in
{
  options.myModule = {
    enable = lib.mkEnableOption "my module";
    setting = lib.mkOption {
      type = lib.types.str;
      default = "value";
      description = "Description of the setting";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ /* ... */ ];
  };
}
```

### Flake Input Access

Modules access flake inputs via the `flake` argument:

```nix
{ flake, pkgs, ... }:
let
  inherit (flake) inputs;
in
{
  home.packages = [
    inputs.some-flake.packages.${pkgs.system}.default
  ];
}
```

### Configuration Hierarchy

```
configurations/darwin/<host>.nix    -> system-level (macOS)
configurations/nixos/<host>.nix     -> system-level (Linux)
configurations/home/<user>.nix      -> user-level (shared across machines)
host.nix: home-manager.users.<user> -> per-machine user overrides
```

### Activation

```bash
nix run .#activate    # Apply configuration
nix run .#update      # Update flake.lock
nix fmt               # Format all .nix files
nix flake check       # Verify evaluation
```
