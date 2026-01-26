# Workflow and Commands

## Daily Operations

### Apply Configuration

**Darwin (macOS):**
```bash
nix run .#activate
```

This detects the current machine (via hostname) and user, then applies:
1. nix-darwin system configuration
2. home-manager user configuration
3. Runs activation scripts

**NixOS (OrbStack VM):**
```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

For the nooks VM specifically:
```bash
sudo nixos-rebuild switch --flake .#nooks
```

### Update Dependencies

```bash
nix run .#update
```

Updates `flake.lock` to latest versions of all inputs.

### Format Code

```bash
nix fmt
```

Formats all Nix files using nixpkgs-fmt.

## Development Workflow

### Making Changes

1. Edit files in `modules/` or `configurations/`
2. Run `nix run .#activate` to apply
3. If activation fails, fix errors and retry

### Testing Changes

```bash
# Build Darwin config without activating:
nix build .#darwinConfigurations.<hostname>.system

# Build NixOS config without activating:
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel

# Check flake evaluation:
nix flake check
```

### Debugging

```bash
# Enter a Nix repl with flake loaded:
nix repl .

# Show what would be built:
nix build .#darwinConfigurations.<hostname>.system --dry-run

# Trace evaluation errors:
nix eval .#darwinConfigurations.<hostname>.system --show-trace
```

## Adding New Configuration

### New Package

Add to `modules/home/packages.nix`:

```nix
home.packages = with pkgs; [
  # ... existing packages
  new-package
];
```

### New Homebrew App

Add to machine config or `modules/darwin/default.nix`:

```nix
homebrew.casks = [
  "new-app"
];
```

### New Module

Create `modules/home/newmodule.nix`:

```nix
{ config, lib, pkgs, ... }:

{
  # Configuration here
}
```

It's automatically imported.

### New Machine

See [machines.md](./machines.md) for instructions.

### New Secret

1. Edit `secrets.yaml`:
   ```bash
   sops secrets.yaml
   ```

2. Add the secret key and value

3. Reference in configuration:
   ```nix
   sops.secrets.new_secret = {
     key = "NEW_SECRET_KEY";
   };
   ```

## Rollback

### nix-darwin Rollback

```bash
# List generations:
darwin-rebuild --list-generations

# Rollback to previous:
darwin-rebuild --rollback
```

### home-manager Rollback

```bash
# List generations:
home-manager generations

# Activate specific generation:
/nix/store/<hash>-home-manager-generation/activate
```

## Garbage Collection

Automatic GC is configured in `modules/home/gc.nix`. Manual cleanup:

```bash
# Remove old generations:
nix-collect-garbage -d

# More aggressive cleanup:
nix store gc
```

## Troubleshooting

### Backup File Conflicts

If activation fails with "file already exists" errors, the backup extension is set in machine configs:

```nix
home-manager.backupFileExtension = "nixos-unified-template-backup";
```

Remove conflicting `.nixos-unified-template-backup` files if needed.

### Secrets Not Decrypting

1. Verify age key exists: `ls ~/.config/sops/age/keys.txt`
2. Check key is authorized in `.sops.yaml`
3. Re-encrypt if needed: `sops updatekeys secrets.yaml`

### Flake Evaluation Errors

```bash
# Get detailed trace:
nix eval .#darwinConfigurations.<hostname>.system --show-trace 2>&1 | less
```

### Build Failures

```bash
# Build with verbose output:
nix build .#darwinConfigurations.<hostname>.system -L
```

## Working with Nooks (OrbStack VM)

### Basic Nook Operations

```bash
# List all nooks and their states
nook list

# Start a nook for a repo/branch
nook start https://github.com/org/repo feature-branch

# Enter a nook interactively
nook enter feature-branch

# Run a command in a nook
nook exec feature-branch "wigg list"

# Release a nook
nook release feature-branch           # Keep worktree (PAUSED)
nook release feature-branch --merge   # Merge to main, clean up
nook release feature-branch --discard # Discard work, clean up
```

### Running wigg in a Nook

```bash
# Enter a nook
nook enter feature-branch

# Inside the nook, verify setup
echo $ANTHROPIC_API_KEY | head -c 20  # Should show: sk-ant-api03-...
wigg list                              # Show available modes

# Run wigg
wigg run plan                          # Planning mode
wigg run build --max-iter=5           # Build mode with iteration limit
```

### Troubleshooting Nooks

| Problem | Solution |
|---------|----------|
| Nook won't start | Check `journalctl -M nook-1` for container logs |
| Secret not available | Verify sops decryption: `sudo ls -la /run/secrets/` |
| wigg not found | Rebuild: `sudo nixos-rebuild switch --flake .#nooks` |
| Pool exhausted | Release unused nooks: `nook release <branch> --discard` |
