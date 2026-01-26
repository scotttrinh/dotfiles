# Machine Configurations

This repository manages both macOS (Darwin) and Linux (NixOS) machines.

## Machine Types

| Type | Platform | Use Case |
|------|----------|----------|
| Darwin | aarch64-darwin | macOS laptops (Apple Silicon) |
| NixOS | aarch64-linux | OrbStack VMs for isolated workloads |

## Configuration Hierarchy

**Darwin machines:**
1. **Base defaults**: `modules/home/` and `modules/darwin/` provide shared configuration
2. **User defaults**: `configurations/home/scotttrinh.nix` sets user identity
3. **Machine overrides**: `configurations/darwin/<hostname>.nix` adds machine-specific settings

**NixOS machines:**
1. **Base modules**: `modules/nixos/orbstack.nix` for OrbStack-specific settings
2. **External modules**: `nooks.nixosModules.default` for container infrastructure
3. **Machine config**: `configurations/nixos/<hostname>.nix` defines the full system

## Darwin Machines

### triangle (Work Laptop)

**File**: `configurations/darwin/triangle.nix`

Work machine with Vercel-specific tooling:

**Homebrew Casks**:
- 1password
- slack
- cursor
- orbstack

**Homebrew Brews**:
- vercel-cli
- supabase

**Additional Packages**:
- git-lfs
- gh (GitHub CLI)

**Claude Code Configuration** (see [settings.md](./settings.md)):
- Auth: OAuth via `CLAUDE_CODE_AUTH_TOKEN_TRIANGLE` secret
- Base URL: `https://ai-gateway.vercel.sh` (Vercel's AI gateway)
- Model: opus
- Status line: enabled

**Activation Script**:
Auto-clones `vercel/front` repository with `pnpm install`

### frannie (Personal Laptop)

**File**: `configurations/darwin/frannie.nix`

Minimal personal machine:

**Claude Code Configuration**:
- Auth: API Key via `CLAUDE_CODE_API_KEY_FRANNIE` secret
- Base URL: `https://api.z.ai/api/anthropic` (z.ai proxy)
- Model: opus

No additional packages beyond base configuration.

### frankie (Personal Laptop)

**File**: `configurations/darwin/frankie.nix`

Minimal configuration with no machine-specific overrides. Inherits all defaults from `self.darwinModules.default`.

## NixOS Machines

### nooks (OrbStack VM)

**File**: `configurations/nixos/nooks.nix`

OrbStack NixOS VM running isolated AI agent containers:

**Purpose**:
- Run wigg + claude-code in sandboxed nook containers
- Full isolation from host macOS system
- Git worktree-based workspace management

**Key Components**:
- **nooks module**: Creates systemd-nspawn containers with network isolation
- **sops-nix**: Decrypts `ANTHROPIC_API_KEY_NOOKS` for API access
- **OrbStack module**: VM-specific settings (DNS, networking, watchdogs)

**Nook Configuration**:
- Container count: 5 (configurable via `services.nook.nookCount`)
- Extra packages: claude-code, wigg (installed in all containers)
- Secrets: `ANTHROPIC_API_KEY` injected via `services.nook.secrets.env`

**Git Workflow**:
- Nooks perform local git operations only (commit, merge, branch updates)
- All GitHub network operations (push/pull/fetch) happen from the VM host
- VM has its own SSH key (not shared with macOS) for independent rotation

**Architecture**:
```
┌─────────────────────────────────────────────────────┐
│ OrbStack NixOS VM (nooks)                           │
│   - sops-nix decrypts secrets                       │
│   - nook CLI manages containers                     │
│                                                     │
│   ┌───────────┐ ┌───────────┐ ┌───────────┐        │
│   │ nook-1    │ │ nook-2    │ │ nook-N    │        │
│   │ - wigg    │ │ - wigg    │ │ - wigg    │        │
│   │ - claude  │ │ - claude  │ │ - claude  │        │
│   │ - $ANTHROPIC_API_KEY                  │        │
│   └───────────┘ └───────────┘ └───────────┘        │
└─────────────────────────────────────────────────────┘
```

**Activation**:
```bash
# Inside the OrbStack VM:
sudo nixos-rebuild switch --flake .#nooks
```

## Common Darwin Configuration

All machines inherit from `self.darwinModules.default`, which provides:

**System (nix-darwin)**:
- Dock: autohide, left position, 32px icons, static apps only
- Finder: show extensions, POSIX path in title, status/path bars
- Keyboard: CapsLock→Ctrl, key mapping
- TouchID for sudo
- Homebrew: ghostty, raycast, Dato

**User (home-manager)**:
- Shell: Zsh with Starship prompt, Zoxide
- Git: Configured with user identity
- Packages: Node.js, Python, Rust, comprehensive CLI tools
- Direnv with nix-direnv
- Emacs setup

## Adding a New Darwin Machine

1. Create `configurations/darwin/<hostname>.nix`:

```nix
{ self, pkgs, lib, ... }:

{
  imports = [ self.darwinModules.default ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  networking.hostName = "<hostname>";

  home-manager.backupFileExtension = "nixos-unified-template-backup";
  home-manager.users.scotttrinh = {
    # Machine-specific overrides here
  };

  system.stateVersion = 4;
}
```

2. Add the machine's age public key to `.sops.yaml` if it needs secrets

3. Re-encrypt secrets if needed: `sops updatekeys secrets.yaml`

4. Run `nix run .#activate` on the new machine

## Adding a New NixOS Machine (OrbStack)

1. Create `configurations/nixos/<hostname>.nix`:

```nix
{ flake, config, pkgs, lib, modulesPath, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    "${modulesPath}/virtualisation/lxc-container.nix"
    self.nixosModules.orbstack
    inputs.nooks.nixosModules.default
    inputs.sops-nix.nixosModules.sops
  ];

  networking.hostName = "<hostname>";

  # User with UID 501 to match macOS
  users.users.scotttrinh = {
    uid = 501;
    isSystemUser = true;
    group = "users";
    extraGroups = [ "wheel" "orbstack" ];
    createHome = true;
    home = "/home/scotttrinh";
  };

  # sops-nix for secrets
  sops = {
    defaultSopsFile = ../../secrets.yaml;
    age.keyFile = "/home/scotttrinh/.config/sops/age/keys.txt";
  };

  # Nook configuration (if using nooks)
  services.nook = {
    enable = true;
    # ...
  };

  system.stateVersion = "25.05";
}
```

2. Generate dedicated age key: `age-keygen -o ~/.config/sops/age/<hostname>.key`

3. Add the public key to `.sops.yaml`

4. Re-encrypt secrets: `sops updatekeys secrets.yaml`

5. Create OrbStack VM: `orb create nixos <hostname>`

6. Inside VM, copy age key and activate:
   ```bash
   mkdir -p ~/.config/sops/age
   cp /mnt/mac/Users/scotttrinh/.config/sops/age/<hostname>.key ~/.config/sops/age/keys.txt
   sudo nixos-rebuild switch --flake .#<hostname>
   ```
