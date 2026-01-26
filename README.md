# Dotfiles on Nix (nixos-unified)

This repository contains the flake-backed configuration that keeps my macOS
machines and Home Manager environment consistent. The setup uses the
[nixos-unified](https://nixos-unified.org) project to stitch together
`nix-darwin`, `home-manager`, overlays, and extra packages behind a single flake.

- `configurations/darwin`: one file per host (e.g. `frankie.nix`)
- `configurations/home`: user-level Home Manager profiles
- `modules`: reusable modules shared by the hosts, organized by domain
- `overlays` & `packages`: custom package definitions layered on top of nixpkgs

## Prerequisites

1. Install Nix using the **multi-user** installer. On macOS, the supported path
   for nixos-unified is Determinate System's installer:
   ```sh
   curl -L https://install.determinate.systems/nix | sh
   ```
   Linux users can follow the same installer or use their distribution's
   recommended multi-user setup.
2. Make sure experimental features are enabled (flakes, nix-command). For the
   Determinate installer this is automatic; on other setups add
   `experimental-features = nix-command flakes` to `/etc/nix/nix.conf`.
3. Clone this repository somewhere convenient (e.g. `~/dev/dotfiles`) and keep
   your shell pointed at that directory when running `nix` commands.

## First-Time Bootstrap on macOS

1. Clone the repo and open a shell inside it.
2. Select (or create) the host configuration file in `configurations/darwin` and
   ensure `networking.hostName` matches the machine's hostname (what `scutil
   --get LocalHostName` reports).
3. Run the unified activation script:
   ```sh
   nix run .#activate
   ```
   This applies the corresponding `nix-darwin` system configuration and your
   Home Manager profile in one go. The command determines the target based on
   `<username>@<host>`; make sure the host file name matches the system's
   hostname.
4. Re-open your terminal (or log out and back in) to pick up shell integrations.

If the activation command fails because the host definition is missing, create a
new one following the next section.

## Adding a New Darwin Host

1. Copy an existing file from `configurations/darwin/` (e.g.
   `frankie.nix`) to a new filename that matches your hostname.
2. Adjust `networking.hostName`, `system.primaryUser`, and any per-machine tweaks
   (overlays, hardware-specific options).
3. Commit the new host file and re-run `nix run .#activate` on the target
   machine.

## Adding a Home Manager-Only User

For machines where you only want the Home Manager profile (no system-level
changes):

1. Duplicate `configurations/home/scotttrinh.nix` to a new filename matching the
   user.
2. Update the `me` attribute set with your username, full name, and email.
3. Activate with:
   ```sh
   nix run .#activate <username>
   ```
   Home Manager will use the modules in `modules/home/` and place files under
   `$HOME`.

## OrbStack NixOS VM (nooks)

This repository includes a NixOS configuration for an OrbStack VM that runs
isolated AI agent containers ("nooks") with `wigg` and `claude-code`.

```
┌─────────────────────────────────────────────────────┐
│ OrbStack NixOS VM (nooks)                           │
│   - sops-nix decrypts ANTHROPIC_API_KEY             │
│   - nook CLI manages containers                     │
│                                                     │
│   ┌───────────┐ ┌───────────┐ ┌───────────┐        │
│   │ nook-1    │ │ nook-2    │ │ nook-N    │        │
│   │ - wigg    │ │ - wigg    │ │ - wigg    │        │
│   │ - claude  │ │ - claude  │ │ - claude  │        │
│   └───────────┘ └───────────┘ └───────────┘        │
└─────────────────────────────────────────────────────┘
```

### Prerequisites

1. **OrbStack** installed on macOS (`brew install --cask orbstack`)
2. **Age key** generated for the nooks VM at `~/.config/sops/age/nooks.key`

### macOS-side Setup

If setting up from scratch, generate the required keys:

```bash
# Generate age key for sops-nix
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/nooks.key

# Add the public key to .sops.yaml and re-encrypt secrets:
# sops updatekeys secrets.yaml

# Create the OrbStack NixOS VM
orb create nixos nooks
```

### VM Bootstrap

Inside the nooks VM (via `ssh nooks@orb` or OrbStack UI):

```bash
# 1. Copy age key from macOS (OrbStack mounts home at /mnt/mac/Users/<username>)
mkdir -p ~/.config/sops/age
cp /mnt/mac/Users/scotttrinh/.config/sops/age/nooks.key ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# 2. Set up VM-specific SSH key for GitHub (replacing OrbStack's default symlinks)
rm -f ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub  # Remove OrbStack symlinks to macOS keys
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "nooks-vm"
# Add the public key to your GitHub account

# 3. Clone dotfiles and activate
git clone git@github.com:scotttrinh/dotfiles.git ~/dotfiles
cd ~/dotfiles
sudo nixos-rebuild switch --flake .#nooks

# 4. Verify the setup
nook list
```

> **Note**: OrbStack automatically creates symlinks from `~/.ssh/` to your macOS SSH keys.
> We replace these with a VM-specific key so it can be rotated independently. SSH access
> to the VM (`ssh nooks@orb`) is handled separately by OrbStack and remains unaffected.

### Verifying the Setup

After bootstrap, verify everything works:

```bash
# Start a test nook
nook start https://github.com/scotttrinh/some-repo test-branch

# Enter the nook
nook enter test-branch

# Inside the nook, verify tools and secrets
echo $ANTHROPIC_API_KEY | head -c 20   # Should show: sk-ant-api03-...
wigg list                               # Show wigg modes
cat ~/.claude/settings.json             # Claude Code config
```

### Nook Workflow Commands

| Command | Description |
|---------|-------------|
| `nook list` | List all nooks and their states |
| `nook start <repo-url> <branch>` | Start a nook for a repo/branch |
| `nook enter <branch>` | Enter a nook interactively |
| `nook exec <branch> "<cmd>"` | Run a command in a nook |
| `nook release <branch>` | Release nook, keep worktree (PAUSED) |
| `nook release <branch> --merge` | Merge to main, clean up |
| `nook release <branch> --discard` | Discard work, clean up |

### Running wigg in a Nook

```bash
nook enter feature-branch

# Inside the nook
wigg list                      # Show available modes
wigg run plan                  # Planning mode
wigg run build --max-iter=5   # Build mode with iteration limit
```

See `.wigg/specs/` for detailed specifications on nook configuration and workflows.

## Updating Inputs

To refresh the flake inputs (nixpkgs, nix-darwin, home-manager, etc.):

```sh
nix run .#update
```

Review the resulting changes in `flake.lock` before committing.

## Troubleshooting

- `nix run .#activate` picks the target from `<username>@<hostname>`. Make sure
  you have matching files in `configurations/home/` and `configurations/darwin/`
  (or `nixos/`) when activating a new machine.
- If Nix complains about flakes being disabled, confirm that
  `nix --version` shows 2.18+ and the experimental features mentioned above are
  enabled.
- Any macOS-specific services (TouchID for sudo, dnsmasq-based resolver, Dock
  settings) are defined under `modules/darwin/default.nix`. Update that module
  when you need system-wide tweaks that apply to multiple hosts.

Refer to [nixos-unified.org](https://nixos-unified.org) for the full upstream
documentation and migration guides.

