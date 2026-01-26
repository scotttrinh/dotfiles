# Dotfiles Architecture Overview

This repository manages system and user configurations for multiple machines using a Nix-based approach, supporting both macOS (nix-darwin) and Linux (NixOS) systems.

## Core Technologies

- **nixos-unified**: Meta-framework that orchestrates flake-parts, nix-darwin, home-manager, and NixOS
- **flake-parts**: Flake structure organization
- **nix-darwin**: macOS system-level configuration (Dock, Finder, keyboard, Homebrew)
- **NixOS**: Linux system-level configuration (used for OrbStack VMs)
- **home-manager**: User environment management (packages, programs, dotfiles)
- **sops-nix**: Encrypted secrets management with age keys (see [secrets.md](./secrets.md))

Tool configuration (model selection, feature flags, etc.) is managed declaratively in Nix modules. See [settings.md](./settings.md) for the pattern.

## External Dependencies

- **nooks**: NixOS module for running isolated AI agent containers
- **wigg**: Autonomous AI development loop CLI
- **llm-agents**: Provides claude-code and other LLM CLI tools

## Directory Structure

```
dotfiles/
├── flake.nix                 # Main entry point
├── flake.lock                # Locked dependency versions
├── configurations/           # Machine and user-level configs
│   ├── darwin/               # macOS host configurations
│   │   ├── triangle.nix      # Work machine
│   │   ├── frannie.nix       # Personal machine
│   │   └── frankie.nix       # Personal machine
│   ├── nixos/                # NixOS host configurations
│   │   └── nooks.nix         # OrbStack VM for AI agent containers
│   └── home/                 # User-level Home Manager configs
│       └── scotttrinh.nix    # Primary user config
├── modules/                  # Reusable, composable modules
│   ├── home/                 # Home Manager modules (auto-imported)
│   ├── darwin/               # nix-darwin modules
│   ├── nixos/                # NixOS modules
│   │   ├── common/           # Shared NixOS config (user management)
│   │   └── orbstack.nix      # OrbStack-specific settings
│   └── flake/                # Flake infrastructure
├── packages/                 # Custom package definitions
├── secrets.yaml              # SOPS-encrypted secrets
└── .sops.yaml                # SOPS configuration with age keys
```

## How nixos-unified Works

The `flake.nix` uses nixos-unified to automatically:

1. Discover Darwin configurations in `configurations/darwin/`
2. Discover NixOS configurations in `configurations/nixos/`
3. Discover user configurations in `configurations/home/`
4. Wire together modules, packages, and flake outputs
5. Provide the `nix run .#activate` command

```nix
outputs = inputs@{ self, ... }:
  inputs.nixos-unified.lib.mkFlake {
    inherit inputs;
    root = ./.;
  };
```

## Configuration Flow

### Darwin (macOS)

```
configurations/darwin/<hostname>.nix
  └─> imports self.darwinModules.default
      ├─> modules/darwin/default.nix (system config)
      └─> home-manager.users.<username>
          └─> merges with configurations/home/<username>.nix
              └─> imports self.homeModules.default
                  └─> auto-imports modules/home/*.nix
```

### NixOS (Linux / OrbStack)

```
configurations/nixos/<hostname>.nix
  └─> imports self.nixosModules.orbstack (for OrbStack VMs)
  └─> imports nooks.nixosModules.default (for nook containers)
  └─> imports sops-nix.nixosModules.sops (for secrets)
  └─> configures services.nook with extraPackages and secrets
```

## Key Inputs

The flake pins to 25.11 branches for stability:

**Core:**
- `nixpkgs` (nixpkgs-25.11-darwin)
- `nix-darwin` (25.11)
- `home-manager` (25.11)
- `flake-parts`
- `nixos-unified`
- `sops-nix`

**Tools:**
- `nix-index-database`
- `rust-overlay`
- `llm-agents` (claude-code, gemini-cli, etc.)
- `nooks` (isolated AI agent containers)
- `wigg` (AI development loop CLI)

## Activation

Running `nix run .#activate`:

1. Detects username@hostname from environment
2. Loads matching `configurations/darwin/<hostname>.nix`
3. Loads matching `configurations/home/<username>.nix`
4. Applies nix-darwin system configuration
5. Runs home-manager switch
6. Executes activation scripts
