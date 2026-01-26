# Implementation Plan: OrbStack NixOS VM for Nooks

Add a NixOS configuration to dotfiles that runs on OrbStack, providing isolated nook containers with wigg + claude-code for autonomous AI development.

## Goal

```
┌─────────────────────────────────────────────────────────────────────┐
│ Mac (triangle) with OrbStack installed                              │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ OrbStack NixOS VM ("nooks")                                   │ │
│  │  - Pulls config from dotfiles                                 │ │
│  │  - Dedicated age key for sops-nix                            │ │
│  │  - nook CLI manages containers                                │ │
│  │                                                               │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐             │ │
│  │  │ nook-1      │ │ nook-2      │ │ nook-N      │             │ │
│  │  │  - wigg     │ │  - wigg     │ │  - wigg     │             │ │
│  │  │  - claude   │ │  - claude   │ │  - claude   │             │ │
│  │  │  - $ANTHROPIC_API_KEY set                   │             │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘             │ │
│  └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Age key for sops | Generate dedicated key | Isolated from macOS keys, can be revoked independently |
| SSH access to nooks | Generate dedicated key | Security isolation, clear audit trail |
| GitHub SSH in nooks | Share from VM | VM's ~/.ssh mounted into nooks, single key to manage |

---

## Tasks

### Create OrbStack NixOS module - P0 - Done

**Spec Reference:** nook/examples/orbstack-host/orbstack.nix

**Goal:** Create a reusable NixOS module with OrbStack-specific configuration that can be imported by any NixOS configuration running in OrbStack.

**Scope:**
- [x] Create `modules/nixos/orbstack/default.nix`
- [x] Include OrbStack CLI path setup (profile-early, profile-late)
- [x] Configure DNS to use OrbStack's resolver
- [x] Disable systemd watchdog services (container environment)
- [x] Configure SSH to include OrbStack config
- [x] Enable emulated architectures (x86_64 on aarch64)
- [x] Create orbstack group with GID 67278

**Implementation:**
- Module created at `modules/nixos/orbstack/default.nix`
- Auto-discovered by nixos-unified autoWire as `nixosModules.orbstack`
- Verified module evaluates correctly in a minimal NixOS-like configuration

**Acceptance Criteria:**
- [x] Module imports without errors when included in a NixOS configuration
- [x] Module follows existing patterns from nook/examples/orbstack-host/orbstack.nix

**Test Strategy:**
- Unit: Include module in a minimal NixOS configuration, verify evaluation succeeds

**Dependencies:** None

**Blockers:** None

---

### Create nooks NixOS configuration - P0 - Ready

**Spec Reference:** nook/examples/orbstack-host/configuration.nix, nook/modules/nooks.nix

**Goal:** Create the main NixOS configuration file for the nooks VM that combines the OrbStack module, nook service, and sops-nix secrets.

**Scope:**
- [ ] Create `configurations/nixos/nooks.nix`
- [ ] Import lxc-container.nix from nixpkgs/virtualisation
- [ ] Import self.nixosModules.orbstack
- [ ] Import nook.nixosModules.default (nook service)
- [ ] Import sops-nix.nixosModules.sops
- [ ] Configure scotttrinh user with UID 501 (match macOS)
- [ ] Configure services.nook with extraPackages (claude-code, wigg)
- [ ] Configure sops secrets for ANTHROPIC_API_KEY
- [ ] Configure systemd-networkd for eth0

**Acceptance Criteria:**
- [ ] Configuration evaluates without errors
- [ ] `nix build .#nixosConfigurations.nooks.config.system.build.toplevel` succeeds

**Test Strategy:**
- Unit: Evaluate configuration with `nix eval`
- Integration: Build the full system configuration

**Dependencies:** Create OrbStack module

**Blockers:** None

---

### Wire up nixos-unified for NixOS configuration discovery - P1 - Ready

**Spec Reference:** https://github.com/srid/nixos-unified

**Goal:** Ensure nixos-unified auto-discovers the NixOS configuration at configurations/nixos/nooks.nix.

**Scope:**
- [ ] Investigate how nixos-unified discovers configurations (check flakeModules.autoWire)
- [ ] Create `modules/nixos/default.nix` if required for module discovery
- [ ] Export nixosModules.orbstack from the flake
- [ ] Verify .#nixosConfigurations.nooks appears in flake outputs

**Acceptance Criteria:**
- [ ] `nix flake show` lists `nixosConfigurations.nooks`
- [ ] `nix build .#nixosConfigurations.nooks.config.system.build.toplevel` works

**Test Strategy:**
- Unit: Run `nix flake show | grep nooks`

**Dependencies:** Create nooks NixOS configuration

**Blockers:** None

---

### Generate and configure age key for nooks VM - P1 - Done

**Spec Reference:** N/A (secrets infrastructure)

**Goal:** Generate a dedicated age key for the nooks VM and update .sops.yaml to include it in encryption recipients.

**Scope:**
- [x] Generate age key: `age-keygen -o ~/.config/sops/age/nooks.key`
- [x] Add public key to `.sops.yaml` as `&age_nooks`
- [x] Add `*age_nooks` to the creation_rules key_groups
- [x] Re-encrypt secrets.yaml with new key: `sops updatekeys secrets.yaml`
- [x] Add `ANTHROPIC_API_KEY_NOOKS` to secrets.yaml

**Implementation:**
- Age key generated at `~/.config/sops/age/nooks.key` on triangle
- Public key: `age1gksfefdf7t6v07t8f6klqff2v5rz97wxwn8jd5kk3zg65j9hqesqt8q37m`
- secrets.yaml re-encrypted with all three keys (frannie, triangle, nooks)
- ANTHROPIC_API_KEY_NOOKS uses the triangle auth token

**Acceptance Criteria:**
- [x] `.sops.yaml` contains the nooks age public key
- [x] `sops -d secrets.yaml` succeeds from a machine with any of the three keys
- [x] `ANTHROPIC_API_KEY_NOOKS` is present in decrypted secrets

**Test Strategy:**
- Manual: Decrypt secrets.yaml on triangle, verify ANTHROPIC_API_KEY_NOOKS exists

**Dependencies:** None

**Blockers:** None

---

### Generate SSH key for nook access - P2 - Ready

**Spec Reference:** N/A (access infrastructure)

**Goal:** Generate a dedicated SSH key pair for accessing nook containers from the macOS host.

**Scope:**
- [ ] Generate key: `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_nooks -C "nooks-access"`
- [ ] Add public key to `configurations/nixos/nooks.nix` authorizedKeys list
- [ ] Document the key's purpose in a comment

**Acceptance Criteria:**
- [ ] SSH key pair exists at ~/.ssh/id_ed25519_nooks
- [ ] Public key is in the nooks.nix authorizedKeys configuration
- [ ] Can SSH to nook containers using: `ssh -i ~/.ssh/id_ed25519_nooks nook@<nook-ip>`

**Test Strategy:**
- Integration: After VM bootstrap, verify SSH access works

**Dependencies:** Create nooks NixOS configuration

**Blockers:** None

---

### Document bootstrap procedure in README - P2 - Ready

**Spec Reference:** N/A (documentation)

**Goal:** Add clear bootstrap instructions to the dotfiles README for setting up the nooks VM.

**Scope:**
- [ ] Add "OrbStack NixOS VM" section to README.md
- [ ] Document prerequisites (OrbStack installed, age key generated)
- [ ] Document macOS-side setup steps
- [ ] Document VM-side bootstrap steps
- [ ] Document how to verify the setup works

**Acceptance Criteria:**
- [ ] README contains complete bootstrap instructions
- [ ] A new user can follow the instructions to set up the VM

**Test Strategy:**
- Manual: Follow the documented steps on a fresh setup

**Dependencies:** All other tasks

**Blockers:** None

---

## Task Summary

| Task | Priority | Status | Dependencies |
|------|----------|--------|--------------|
| Create OrbStack NixOS module | P0 | **Done** | None |
| Create nooks NixOS configuration | P0 | Ready | OrbStack module |
| Wire up nixos-unified for NixOS config discovery | P1 | Ready | NixOS configuration |
| Generate and configure age key for nooks VM | P1 | **Done** | None |
| Generate SSH key for nook access | P2 | Ready | NixOS configuration |
| Document bootstrap procedure in README | P2 | Ready | All implementation tasks |

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

## References

- nook/examples/orbstack-host/ - Example OrbStack configuration
- nook/modules/nooks.nix - Full module options (nook service configuration)
- nixos-unified docs - https://github.com/srid/nixos-unified
