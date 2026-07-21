# Secrets Management

Secrets are managed using **sops-nix** with **age** encryption keys.

## Overview

- Secrets are stored in per-machine files under `secrets/`
- Each machine has its own age key pair
- `.sops.yaml` defines which keys can decrypt which secrets
- Secrets are decrypted at activation time

> **Note**: For non-sensitive configuration (model selection, feature flags, UI preferences), see [settings.md](./settings.md). This document covers sensitive credentials only.

## Configuration Files

### `.sops.yaml`

Defines encryption rules and authorized keys:

```yaml
keys:
  - &frannie age1...  # frannie's public key
  - &triangle age1... # triangle's public key
  - &nooks age1...    # nooks VM's public key

creation_rules:
  - path_regex: secrets/triangle\.ya?ml$
    key_groups:
      - age:
          - *triangle
  - path_regex: secrets/frannie\.ya?ml$
    key_groups:
      - age:
          - *frannie
  - path_regex: secrets/nooks\.ya?ml$
    key_groups:
      - age:
          - *nooks
```

### `secrets/<machine>.yaml`

Each machine has a flat encrypted file containing only its own credentials. For example:

```yaml
AI_GATEWAY_API_KEY: ENC[...]
EMACS_AUTHINFO: ENC[...]
```

## How Secrets Are Used

### 1. Define Secret in Module

```nix
# In machine config or module:
sops.secrets.claude_code_auth_token = {
  key = "AI_GATEWAY_API_KEY";
  mode = "0400";
};
```

### 2. Reference in Configuration

Use `sops.placeholder.*` or `sops.secrets.*.path`:

```nix
# In a template (recommended for config files):
sops.templates."claude-settings" = {
  content = builtins.toJSON {
    apiKey = config.sops.placeholder.claude_code_auth_token;
  };
  path = "${config.home.homeDirectory}/.claude/settings.json";
};

# Or reference the file path directly:
environment.variables.SECRET_FILE = config.sops.secrets.my_secret.path;
```

### 3. Default Settings

**Home Manager (Darwin)** - set in each machine configuration:

```nix
sops = {
  defaultSopsFile = ../../secrets/triangle.yaml;
  age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
};
```

**NixOS** - configured per-machine in `configurations/nixos/<hostname>.nix`:

```nix
sops = {
  defaultSopsFile = ../../secrets/nooks.yaml;
  age.keyFile = "/home/scotttrinh/.config/sops/age/keys.txt";
};
```

### 4. NixOS Secrets for Nooks

Nook containers receive secrets via the nooks module:

```nix
# Decrypt secret on the NixOS host
sops.secrets.anthropic_api_key = {
  key = "AI_GATEWAY_API_KEY";
};

# Inject into all nook containers as environment variable
services.nook.secrets.env = {
  ANTHROPIC_API_KEY = config.sops.secrets.anthropic_api_key.path;
};
```

The nooks module:
1. Reads the decrypted file from `/run/secrets/anthropic_api_key`
2. Bind-mounts it into containers at `/run/host-secrets/ANTHROPIC_API_KEY`
3. A systemd service reads the file and sets the environment variable
4. All shell sessions in nooks have `$ANTHROPIC_API_KEY` available

## Machine Setup

### Generate Age Key

On a new machine, generate an age key pair:

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

### Get Public Key

```bash
age-keygen -y ~/.config/sops/age/keys.txt
```

### Add to `.sops.yaml`

Add the public key to the keys section and creation rules:

```yaml
keys:
  - &newmachine age1...

creation_rules:
  - path_regex: secrets\.yaml$
    key_groups:
      - age:
          - *newmachine
          - *frannie
          - *triangle
```

### Re-encrypt Secrets

After updating `.sops.yaml`:

```bash
sops updatekeys secrets/<machine>.yaml
```

## Editing Secrets

```bash
# Edit secrets for one machine (decrypts, opens editor, re-encrypts on save)
sops secrets/<machine>.yaml

# View decrypted secrets (for debugging)
sops -d secrets/<machine>.yaml
```

## Per-Machine Secrets

Each machine has a separate flat file encrypted only to its own age recipient:

```yaml
# In secrets/triangle.yaml:
AI_GATEWAY_API_KEY: ENC[...]
EMACS_AUTHINFO: ENC[...]
```

Each machine references only its own file in its configuration.

## Security Notes

- Age private keys stay on their respective machines
- Never commit unencrypted secrets
- Secrets are decrypted to `/run/user/<uid>/secrets.d/` at runtime
- File permissions are set per-secret (default 0400)
