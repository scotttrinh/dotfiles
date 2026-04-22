# Dotfiles on Nix (nixos-unified)

This repository contains the flake-backed configuration that keeps my macOS
machines, NixOS VMs, and Home Manager environment consistent. The setup uses
[nixos-unified](https://nixos-unified.org) to stitch together `nix-darwin`,
`nixos`, `home-manager`, and custom packages behind a single flake.

## Repository Structure

```
dotfiles/
├── flake.nix                    # Entry point: inputs, outputs, and nixos-unified wiring
├── flake.lock                   # Pinned dependency versions
├── .sops.yaml                   # SOPS age key mapping (which keys decrypt which secrets)
├── secrets.yaml                 # Encrypted secrets (API keys, tokens)
│
├── configurations/
│   ├── darwin/                  # One file per macOS host
│   │   ├── frankie.nix          #   Minimal personal machine
│   │   ├── frannie.nix          #   Personal machine with Claude Code (API key auth)
│   │   └── triangle.nix         #   Work machine with Claude Code (OAuth), Vercel tooling
│   ├── nixos/                   # One file per NixOS host
│   │   └── nooks.nix            #   OrbStack VM for AI agent containers
│   └── home/                    # User-level Home Manager profiles
│       └── scotttrinh.nix       #   Base user config (imports all home modules)
│
├── modules/
│   ├── home/                    # Home Manager modules (auto-imported)
│   │   ├── packages.nix         #   CLI tools, dev tools, LLM tools
│   │   ├── shell.nix            #   Zsh, starship prompt, aliases
│   │   ├── git.nix              #   Git config, global gitignore
│   │   ├── claude-code/         #   Claude Code settings + auth module
│   │   ├── aerospace/           #   Tiling window manager config
│   │   ├── direnv.nix           #   nix-direnv integration
│   │   ├── emacs.nix            #   Emacs with tree-sitter
│   │   ├── sops.nix             #   Secrets integration (age key path)
│   │   └── ...                  #   gc, nix-index, me, opencode, gemini-cli
│   ├── darwin/                  # Shared macOS system settings
│   │   └── default.nix          #   Dock, Finder, keyboard, Homebrew, TouchID sudo
│   ├── nixos/                   # Shared NixOS modules
│   │   ├── common/              #   User management, home-manager wiring, caches
│   │   └── orbstack/            #   OrbStack container-specific tweaks
│   └── flake/                   # Flake infrastructure (nixos-unified glue)
│
└── packages/                    # Custom package definitions (manually imported)
    ├── pi.nix                   #   Wrapper script around `uvx pi@latest`
    └── ty.nix                   #   Rust type checker (built from source)
```

### How Auto-Discovery Works

nixos-unified automatically discovers and exports configurations based on
directory conventions:

- Files in `configurations/darwin/` become `darwinConfigurations.<filename>`
- Files in `configurations/nixos/` become `nixosConfigurations.<filename>`
- Files in `configurations/home/` become `homeConfigurations.<filename>`
- Files in `modules/` are available as `darwinModules`, `nixosModules`, `homeModules`
- Files in `packages/` are available as `packages.<system>.<name>`

Within `modules/home/`, a `default.nix` uses `builtins.readDir` to auto-import
every `.nix` file in the directory, so adding a new module is just creating a
new file.

## Per-Machine Customization

All machines share the same base home-manager profile
(`configurations/home/scotttrinh.nix`) and the same set of home modules. Host
configurations then layer on machine-specific settings:

| Host | Platform | Notable Differences |
|------|----------|---------------------|
| **frankie** | aarch64-darwin | Minimal — just the shared defaults |
| **frannie** | aarch64-darwin | Claude Code via API key (secret: `CLAUDE_CODE_API_KEY_FRANNIE`) |
| **triangle** | aarch64-darwin | Work machine — Claude Code via OAuth, Vercel CLI, git-lfs, work repo cloning activation script, extra Homebrew casks (1Password, Slack, Cursor, OrbStack) |
| **nooks** | aarch64-linux | OrbStack NixOS VM — runs `nook` containers for AI agent development, injects Claude Code config into containers |

Per-machine overrides happen in the host file itself, which can extend the
home-manager config inline:

```nix
# configurations/darwin/triangle.nix (simplified)
home-manager.users.${config.system.primaryUser}.imports = [
  {
    programs.claude-code = {
      authentication = "oauth";
      baseUrl = "https://ai-gateway.vercel.sh/anthropic/";
    };
    home.packages = with pkgs; [ git-lfs gh ];
  }
];
```

## Custom Packages

Custom packages live in `packages/` as plain Nix functions. They are **not**
auto-discovered — each one must be explicitly imported where it's used.
Currently they're imported in `modules/home/packages.nix`:

```nix
home.packages = [
  (import (flake.inputs.self + /packages/pi.nix) { inherit pkgs; })
  (import (flake.inputs.self + /packages/ty.nix) { inherit flake pkgs; })
];
```

Two patterns are used:

1. **Shell wrapper** (`pi.nix`) — a `writeShellScriptBin` that wraps an
   external tool (`uvx pi@latest`).

2. **Rust package from source** (`ty.nix`) — uses `rustPlatform.buildRustPackage`
   to fetch, build, and install a Rust project from GitHub with shell
   completions.

## Secrets Management (SOPS + age)

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) using
[age](https://github.com/FiloSottile/age) encryption.

### How It Works

1. **`.sops.yaml`** maps age public keys to devices. Each machine has its own
   age keypair, and all secrets are encrypted to all device keys so any machine
   can decrypt them.

2. **`secrets.yaml`** is the encrypted secrets file. It contains API keys and
   tokens as SOPS-encrypted YAML values. Edit with `sops secrets.yaml`.

3. **Home module** (`modules/home/sops.nix`) imports sops-nix and points it at
   the secrets file and the local age key (`~/.config/sops/age/keys.txt`).

4. **Usage in modules** — secrets are declared and then referenced via SOPS
   templates or placeholders:
   ```nix
   # Declare a secret
   sops.secrets.CLAUDE_CODE_API_KEY_FRANNIE = {};

   # Use it in a generated file via sops.templates
   sops.templates."settings.json".content = builtins.toJSON {
     env = {
       ANTHROPIC_API_KEY = config.sops.placeholder.CLAUDE_CODE_API_KEY_FRANNIE;
     };
   };
   ```

### Adding a New Machine's Key

```bash
# Generate age key
age-keygen -o ~/.config/sops/age/keys.txt

# Add the public key to .sops.yaml under the creation_rules keys list
# Then re-encrypt secrets so the new key can decrypt them:
sops updatekeys secrets.yaml
```

## Git Commit Signing

Git commit and tag signing in this repo uses **SSH signing**. On macOS, the
default path assumes [Secretive](https://github.com/maxgoedjen/secretive) with
the private key living in the Secure Enclave.

- `me.gitSigning.enable = true` turns on `gpg.format = ssh`,
  `commit.gpgsign = true`, and `tag.gpgSign = true`
- `modules/home/secretive.nix` configures all Darwin hosts to use Secretive's
  agent socket for both `ssh` and Git signing
- Home Manager writes `~/.gitallowedsigners` so `git verify-commit`,
  `git verify-tag`, and `git log --show-signature` work locally

You cannot reuse the SOPS key at `~/.config/sops/age/keys.txt` for Git commit
signing. An `AGE-SECRET-KEY-...` key is an `age` encryption key; Git signing
expects an SSH, OpenPGP, or X.509 key.

### Secretive Setup on macOS

All Darwin hosts install the `secretive` Homebrew cask and set:

- `SSH_AUTH_SOCK` to Secretive's agent socket in new shells
- `programs.ssh.matchBlocks."*".identityAgent` to the same socket
- Git's SSH signing program to a wrapper that exports that socket explicitly

That means Git signing does not depend on the ambient macOS launchd agent.

### Per-Host Key Setup

On each Mac:

1. Open Secretive and create a signing key in Secure Enclave.
2. Give it a comment that contains `GitHub-Commit-Signing@secretive`.
3. Add the public key to GitHub under **Settings -> SSH and GPG keys** as a
   **Signing Key**.
4. Run `nix run .#activate`.
5. Open a new terminal so the shell picks up `SSH_AUTH_SOCK` for general SSH
   usage.

The shared macOS config can discover the signing key from the Secretive agent
by comment. If you want a specific host to pin an exact public key instead,
override `me.gitSigning.publicKey` in that host config. `triangle` does this in
[`configurations/darwin/triangle.nix`](configurations/darwin/triangle.nix).

### Verification

```bash
git commit --allow-empty -m "test signing"
git log --show-signature -1
```

If you prefer a file-backed SSH key instead of Secretive on a Darwin host,
override `me.gitSigning.agentSocket = null;`, set
`me.gitSigning.agentKeyCommentPattern = null;`, and then point
`me.gitSigning.keyFile` at the key you want Git to use.

## Shared macOS System Settings

All Darwin hosts inherit `modules/darwin/default.nix`, which configures:

- **Nix**: Managed by Determinate Systems (not `nix.enable`), with extra
  binary caches (numtide)
- **TouchID for sudo**: `security.pam.services.sudo_local.touchIdAuth = true`
- **Dock**: Autohide, left-positioned, 32px tile size
- **Finder**: Full POSIX path in title, show all extensions, quit menu enabled
- **Keyboard**: Caps Lock remapped to Control
- **Trackpad**: Tap-to-click, secondary click enabled
- **Homebrew**: Ghostty, Raycast, OpenCode Desktop, Secretive (casks), Dato (App Store)

Individual hosts can add more Homebrew packages or system settings on top.

## Prerequisites

1. Install Nix using the **Determinate Systems** installer:
   ```sh
   curl -L https://install.determinate.systems/nix | sh
   ```
2. Flakes and `nix-command` are enabled automatically by the Determinate
   installer. On other Nix installs, add `experimental-features = nix-command
   flakes` to `/etc/nix/nix.conf`.
3. Clone this repository and run commands from inside it.

## First-Time Bootstrap on macOS

1. Clone the repo and `cd` into it.
2. Ensure a host configuration file exists in `configurations/darwin/` with a
   filename matching your machine's hostname (`scutil --get LocalHostName`).
3. Run the unified activation:
   ```sh
   nix run .#activate
   ```
   This applies the nix-darwin system configuration and Home Manager profile in
   one shot. The target is determined by `<username>@<hostname>`.
4. Re-open your terminal to pick up shell integrations.

## Adding a New Darwin Host

1. Copy an existing file from `configurations/darwin/` to a new file matching
   your hostname.
2. Set `networking.hostName`, `system.primaryUser`, and any per-machine tweaks.
3. If the machine needs secrets, generate an age key and add it to `.sops.yaml`.
4. Create a Secretive signing key on that Mac and add its public key to GitHub
   as a **Signing Key**.
5. Commit and run `nix run .#activate`.

## Adding a Home Manager-Only User

For machines where you only want the Home Manager profile (no system-level
changes):

1. Duplicate `configurations/home/scotttrinh.nix`.
2. Update the `me` attribute set with your username, full name, and email.
3. Activate with:
   ```sh
   nix run .#activate <username>
   ```

## OrbStack NixOS VM (nooks)

The `nooks` host is a NixOS VM running in OrbStack that manages isolated AI
agent containers. See [`configurations/nixos/NOOKS.md`](configurations/nixos/NOOKS.md)
for setup and usage instructions.

## Updating Inputs

```sh
nix run .#update
```

Review changes in `flake.lock` before committing.

## Troubleshooting

- **Activation target mismatch**: `nix run .#activate` resolves the target from
  `<username>@<hostname>`. Make sure matching files exist in
  `configurations/home/` and `configurations/darwin/` (or `nixos/`).
- **Flakes disabled**: Confirm `nix --version` shows 2.18+ and experimental
  features are enabled.
- **macOS system settings**: Shared Dock/Finder/keyboard settings live in
  `modules/darwin/default.nix`. Per-host overrides go in the host's
  configuration file.
- **Secrets errors**: Ensure `~/.config/sops/age/keys.txt` exists and contains
  the correct age private key for this machine. Run `sops secrets.yaml` to
  verify you can decrypt.

Refer to [nixos-unified.org](https://nixos-unified.org) for upstream
documentation.
