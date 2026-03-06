# OrbStack NixOS VM (nooks)

A NixOS configuration for an OrbStack VM that runs isolated AI agent containers
("nooks") with `claude-code`.

```
┌─────────────────────────────────────────────────────┐
│ OrbStack NixOS VM (nooks)                           │
│   - sops-nix decrypts ANTHROPIC_API_KEY             │
│   - nook CLI manages containers                     │
│                                                     │
│   ┌───────────┐ ┌───────────┐ ┌───────────┐        │
│   │ nook-1    │ │ nook-2    │ │ nook-N    │        │
│   │ - claude  │ │ - claude  │ │ - claude  │        │
│   └───────────┘ └───────────┘ └───────────┘        │
└─────────────────────────────────────────────────────┘
```

## macOS-side Setup

```bash
# Generate age key for the VM
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/nooks.key

# Add the public key to .sops.yaml and re-encrypt:
# sops updatekeys secrets.yaml

# Create the OrbStack NixOS VM
orb create nixos nooks
```

## VM Bootstrap

Inside the nooks VM (via `ssh nooks@orb`):

```bash
# 1. Copy age key from macOS (OrbStack mounts home at /mnt/mac/Users/<username>)
mkdir -p ~/.config/sops/age
cp /mnt/mac/Users/scotttrinh/.config/sops/age/nooks.key ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# 2. Set up VM-specific SSH key for GitHub
rm -f ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "nooks-vm"
# Add the public key to your GitHub account

# 3. Clone dotfiles and activate
git clone git@github.com:scotttrinh/dotfiles.git ~/dotfiles
cd ~/dotfiles
sudo nixos-rebuild switch --flake .#nooks

# 4. Verify
nook list
```

> **Note**: OrbStack creates symlinks from `~/.ssh/` to your macOS SSH keys.
> We replace these with a VM-specific key so it can be rotated independently.
> SSH access to the VM (`ssh nooks@orb`) is handled separately by OrbStack.

## Nook Commands

| Command | Description |
|---------|-------------|
| `nook list` | List all nooks and their states |
| `nook start <repo-url> <branch>` | Start a nook for a repo/branch |
| `nook enter <branch>` | Enter a nook interactively |
| `nook exec <branch> "<cmd>"` | Run a command in a nook |
| `nook release <branch>` | Release nook, keep worktree (PAUSED) |
| `nook release <branch> --merge` | Merge to main, clean up |
| `nook release <branch> --discard` | Discard work, clean up |

## Configuration Details

The NixOS configuration (`nooks.nix`) sets up:

- **User**: `scotttrinh` with UID 501 (matches macOS for OrbStack file sharing)
- **Nook service**: 5 containers managed by `services.nook`
- **Secrets**: SOPS-nix decrypts `ANTHROPIC_API_KEY_NOOKS` at activation
- **Injected files**: Claude Code settings and context files are written into
  each nook container via `services.nook.settings.files`
- **Networking**: systemd-networkd with DHCP, SSH with GitHub host key
  verification
- **Packages**: git, vim, curl, tmux, ripgrep, jq, claude-code, nook CLI
