# Secrets Management

Secrets are managed using **sops-nix** with **age** encryption keys.

## Overview

- Secrets are stored encrypted in `secrets.yaml`
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
  - path_regex: secrets\.yaml$
    key_groups:
      - age:
          - *frannie
          - *triangle
          - *nooks
```

### `secrets.yaml`

Encrypted secrets file. Structure:

```yaml
# Darwin machines
CLAUDE_CODE_AUTH_TOKEN_TRIANGLE: ENC[...]
CLAUDE_CODE_API_KEY_FRANNIE: ENC[...]

# NixOS machines
ANTHROPIC_API_KEY_NOOKS: ENC[...]
```

## How Secrets Are Used

### 1. Define Secret in Module

```nix
# In machine config or module:
sops.secrets.claude_code_auth_token = {
  key = "CLAUDE_CODE_AUTH_TOKEN_TRIANGLE";
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

**Home Manager (Darwin)** - from `modules/home/sops.nix`:

```nix
sops = {
  defaultSopsFile = ../../secrets.yaml;
  age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
};
```

**NixOS** - configured per-machine in `configurations/nixos/<hostname>.nix`:

```nix
sops = {
  defaultSopsFile = ../../secrets.yaml;
  age.keyFile = "/home/scotttrinh/.config/sops/age/keys.txt";
};
```

### 4. NixOS Secrets for Nooks

Nook containers receive secrets via the nooks module:

```nix
# Decrypt secret on the NixOS host
sops.secrets.anthropic_api_key = {
  key = "ANTHROPIC_API_KEY_NOOKS";
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
sops updatekeys secrets.yaml
```

## Editing Secrets

```bash
# Edit secrets (decrypts, opens editor, re-encrypts on save)
sops secrets.yaml

# View decrypted secrets (for debugging)
sops -d secrets.yaml
```

## Per-Machine Secrets

Secrets can be machine-specific by using different keys:

```yaml
# In secrets.yaml:
CLAUDE_CODE_AUTH_TOKEN_TRIANGLE: "token-for-triangle"
CLAUDE_CODE_API_KEY_FRANNIE: "key-for-frannie"
```

Each machine references only its own secrets in its configuration.

## Security Notes

- Age private keys stay on their respective machines
- Never commit unencrypted secrets
- Secrets are decrypted to `/run/user/<uid>/secrets.d/` at runtime
- File permissions are set per-secret (default 0400)
