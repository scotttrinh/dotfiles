# Implementation Plan: OrbStack NixOS VM for Nooks

Add a NixOS configuration to dotfiles that runs on OrbStack, providing isolated nook containers with wigg + claude-code for autonomous AI development.

## Goal

```
+---------------------------------------------------------------------+
| Mac (triangle) with OrbStack installed                              |
|                                                                     |
|  +---------------------------------------------------------------+ |
|  | OrbStack NixOS VM ("nooks")                                   | |
|  |  - Pulls config from dotfiles                                 | |
|  |  - Dedicated age key for sops-nix                            | |
|  |  - nook CLI manages containers                                | |
|  |                                                               | |
|  |  +-------------+ +-------------+ +-------------+             | |
|  |  | nook-1      | | nook-2      | | nook-N      |             | |
|  |  |  - wigg     | |  - wigg     | |  - wigg     |             | |
|  |  |  - claude   | |  - claude   | |  - claude   |             | |
|  |  |  - $ANTHROPIC_API_KEY set                   |             | |
|  |  +-------------+ +-------------+ +-------------+             | |
|  +---------------------------------------------------------------+ |
+---------------------------------------------------------------------+
```

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Age key for sops | Generate dedicated key | Isolated from macOS keys, can be revoked independently |
| SSH access to nooks | Generate dedicated key | Security isolation, clear audit trail |
| GitHub SSH in nooks | Share from VM | VM's ~/.ssh mounted into nooks, single key to manage |

---

## Completed Tasks

### Generate SSH key for nook access - P2 - Done

**Spec Reference:** N/A (access infrastructure)

**Goal:** Generate a dedicated SSH key pair for accessing nook containers from the macOS host.

**Implementation:**
- SSH key generated at `~/.ssh/id_ed25519_nooks`
- Public key added to `configurations/nixos/nooks.nix` authorizedKeys
- TODO comment removed from nooks.nix

**Acceptance Criteria:**
- [x] SSH key pair exists at ~/.ssh/id_ed25519_nooks
- [x] Public key is in the nooks.nix authorizedKeys configuration
- [x] Can SSH to nook containers using: `ssh -i ~/.ssh/id_ed25519_nooks nook@<nook-ip>`

---

### Create OrbStack NixOS module - P0 - Done

**Spec Reference:** nook/examples/orbstack-host/orbstack.nix

**Goal:** Create a reusable NixOS module with OrbStack-specific configuration that can be imported by any NixOS configuration running in OrbStack.

**Implementation:**
- Module created at `modules/nixos/orbstack/default.nix`
- Auto-discovered by nixos-unified autoWire as `nixosModules.orbstack`
- Verified module evaluates correctly in a minimal NixOS-like configuration

---

### Create nooks NixOS configuration - P0 - Done

**Spec Reference:** nook/examples/orbstack-host/configuration.nix, nook/modules/nooks.nix

**Goal:** Create the main NixOS configuration file for the nooks VM that combines the OrbStack module, nook service, and sops-nix secrets.

**Implementation:**
- Configuration created at `configurations/nixos/nooks.nix`
- Auto-discovered by nixos-unified autoWire as `nixosConfigurations.nooks`
- Includes all required imports: lxc-container.nix, orbstack module, nook module, sops-nix
- User scotttrinh configured with UID 501 for OrbStack file sharing
- services.nook configured with claude-code and wigg from flake inputs
- SOPS secret `ANTHROPIC_API_KEY_NOOKS` injected into nooks via `services.nook.secrets.env`
- systemd-networkd configured for eth0 with DHCP

---

### Wire up nixos-unified for NixOS configuration discovery - P1 - Done

**Spec Reference:** https://github.com/srid/nixos-unified

**Goal:** Ensure nixos-unified auto-discovers the NixOS configuration at configurations/nixos/nooks.nix.

**Implementation:**
- nixos-unified autoWire automatically discovers configurations at `configurations/nixos/*.nix`
- No additional `modules/nixos/default.nix` was required
- `nixosModules.orbstack` is auto-exported by autoWire from `modules/nixos/orbstack/default.nix`
- Note: Files must be tracked by git (staged or committed) for autoWire to discover them

---

### Generate and configure age key for nooks VM - P1 - Done

**Spec Reference:** N/A (secrets infrastructure)

**Goal:** Generate a dedicated age key for the nooks VM and update .sops.yaml to include it in encryption recipients.

**Implementation:**
- Age key generated at `~/.config/sops/age/nooks.key` on triangle
- Public key: `age1gksfefdf7t6v07t8f6klqff2v5rz97wxwn8jd5kk3zg65j9hqesqt8q37m`
- secrets.yaml re-encrypted with all three keys (frannie, triangle, nooks)
- ANTHROPIC_API_KEY_NOOKS uses the triangle auth token

---

### Configure services.nook.settings for Claude Code - P1 - Done

**Spec Reference:** specs/settings.md (Relationship to Nooks section), nook settings.md spec

**Goal:** Inject Claude Code settings into nook containers using `services.nook.settings.files` so claude-code has consistent configuration inside containers.

**Implementation:**
- Added `services.nook.settings.files` configuration to `configurations/nixos/nooks.nix`
- Configured `/home/nook/.claude/settings.json` with model selection (claude-sonnet-4-20250514)
- Added `/home/nook/.claude/CLAUDE.md` with nook-specific context for Claude Code
- Updated flake.lock to pull in latest nook module with settings support
- Verified settings files are properly injected into nook containers on startup

**Acceptance Criteria:**
- [x] `services.nook.settings.files` is configured in nooks.nix
- [x] After rebuild, `nook enter <branch>` and `cat ~/.claude/settings.json` shows expected config
- [x] Claude Code inside nooks uses the configured model

---

## Pending Tasks

### Document bootstrap procedure in README - P2 - Ready

**Spec Reference:** N/A (documentation)

**Goal:** Add clear bootstrap instructions to the dotfiles README for setting up the nooks VM.

**Scope:**
- [ ] Add "OrbStack NixOS VM" section to README.md
- [ ] Document prerequisites (OrbStack installed, age key generated)
- [ ] Document macOS-side setup steps
- [ ] Document VM-side bootstrap steps
- [ ] Document how to verify the setup works
- [ ] Include nook workflow commands (list, start, enter, release)

**Acceptance Criteria:**
- [ ] README contains complete bootstrap instructions
- [ ] A new user can follow the instructions to set up the VM
- [ ] README references appropriate spec files for details

**Test Strategy:**
- Manual: Follow the documented steps on a fresh setup

**Dependencies:** All other tasks

**Blockers:** None

---

## Task Summary

| Task | Priority | Status | Dependencies |
|------|----------|--------|--------------|
| Create OrbStack NixOS module | P0 | **Done** | None |
| Create nooks NixOS configuration | P0 | **Done** | OrbStack module |
| Wire up nixos-unified for NixOS config discovery | P1 | **Done** | NixOS configuration |
| Generate and configure age key for nooks VM | P1 | **Done** | None |
| Configure services.nook.settings for Claude Code | P1 | **Done** | None |
| Generate SSH key for nook access | P2 | **Done** | NixOS configuration |
| Document bootstrap procedure in README | P2 | Ready | All implementation tasks |

---

## Bootstrap Procedure

### One-time setup on macOS (triangle):

**Already completed:**
- Age key generated at `~/.config/sops/age/nooks.key`
- Public key added to `.sops.yaml`
- secrets.yaml re-encrypted with nooks key
- `ANTHROPIC_API_KEY_NOOKS` added to secrets.yaml

**Remaining steps:**
```bash
# 1. Generate SSH key for nook access
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_nooks -C "nooks-access"
# Add public key to configurations/nixos/nooks.nix authorizedKeys

# 2. Create OrbStack NixOS VM
orb create nixos nooks
```

### Inside the nooks VM:

```bash
# 1. Copy age key from macOS (OrbStack mounts home at /mnt/mac/Users/scotttrinh)
mkdir -p ~/.config/sops/age
cp /mnt/mac/Users/scotttrinh/.config/sops/age/nooks.key ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# 2. Generate SSH key for GitHub (inside VM)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "nooks-vm-github"
# Add public key to GitHub account

# 3. Clone dotfiles and activate
git clone git@github.com:scotttrinh/dotfiles.git ~/dotfiles
cd ~/dotfiles
sudo nixos-rebuild switch --flake .#nooks

# 4. Verify nooks work
nook list
nook start https://github.com/scotttrinh/some-repo test-branch
nook enter test-branch
# Inside nook: wigg list && echo $ANTHROPIC_API_KEY | head -c 20
```

---

## References

- nook/examples/orbstack-host/ - Example OrbStack configuration
- nook/modules/nooks.nix - Full module options (nook service configuration, settings.files)
- nixos-unified docs - https://github.com/srid/nixos-unified
- .wigg/specs/settings.md - Settings management patterns
