---
name: use-nixos-unified
description: Helps users perform day-to-day tasks in an existing nixos-unified dotfiles repo — adding packages, configuring programs, managing secrets, updating inputs, and more. Use when someone wants to make changes to their Nix configuration.
---

# Use Your nixos-unified Dotfiles

> A task-oriented skill for making changes to an existing nixos-unified dotfiles repo. The user says what they want, and you figure out where and how to do it.

## Discovery

Before doing anything, understand the current repo state.

### Required

Read `flake.nix` to understand:
- What inputs are available (and their branch/version)
- Whether `nixos-unified.lib.mkFlake` is used with `root = ./.;` (auto-discovery)

### Scan Structure

Use Glob and Read to understand what exists:

```
configurations/darwin/*.nix   -> darwinConfigurations
configurations/nixos/*.nix    -> nixosConfigurations
configurations/home/*.nix     -> homeConfigurations
modules/home/                 -> homeModules (auto-imported)
modules/darwin/               -> darwinModules
modules/nixos/                -> nixosModules
packages/                     -> custom packages
secrets.yaml                  -> SOPS-encrypted secrets (if present)
.sops.yaml                    -> SOPS key configuration (if present)
```

Read the home module auto-import file (`modules/home/default.nix`) to confirm the import pattern — typically:

```nix
imports = with builtins;
  map (fn: ./${fn})
    (filter (fn: fn != "default.nix") (attrNames (readDir ./.)));
```

This means **every `.nix` file and subdirectory with `default.nix`** in `modules/home/` is automatically imported.

## Searching for Packages and Flakes

Before adding packages or inputs, you may need to search for the correct name. Use these tools:

### Finding nixpkgs Packages

Use `nix search` to find packages by name or description:

```bash
# Search with JSON output for structured results
nix search nixpkgs --json <term>

# Examples:
nix search nixpkgs --json ripgrep
nix search nixpkgs --json "python 3"
nix search nixpkgs --json nodejs
```

The JSON output includes the attribute path (e.g., `legacyPackages.aarch64-darwin.ripgrep`), description, and version. The package name to use in `home.packages` is the last segment of the attribute path (e.g., `ripgrep`).

Note: First invocation is slow (~30s) as it evaluates nixpkgs. Subsequent searches are cached.

### Finding Which Package Provides a Binary

Use `nix-locate` to find which package provides a specific binary:

```bash
nix-locate --whole-name bin/<binary-name>
```

This uses the `nix-index-database` (already an input in this repo). Results may include bundled copies inside other packages — look for the top-level package entry (the one with just `<package>.out` as the prefix).

### Finding and Adding Flake Inputs

Use the **FlakeHub CLI** (`fh`) to search for flakes and add them to `flake.nix`:

```bash
# Search for flakes on FlakeHub
nix run nixpkgs#fh -- search <query>

# Add a flake input directly to flake.nix (modifies the file for you)
nix run nixpkgs#fh -- add <owner>/<repo>

# Examples:
nix run nixpkgs#fh -- search sops-nix
nix run nixpkgs#fh -- add Mic92/sops-nix
nix run nixpkgs#fh -- add DeterminateSystems/nix-index-database
```

`fh add` handles writing the input to `flake.nix` and updating the lock file. After adding, you may still need to:
- Add `follows` for `nixpkgs` if `fh` didn't set it
- Import any modules the flake provides

If a flake isn't on FlakeHub, fall back to manually editing `flake.nix` with a `github:` URL.

### Checking Home-Manager Options

To check if home-manager has a module for a program, use WebFetch on the home-manager option search:

```
https://home-manager-options.extranix.com/?query=<program>&release=master
```

Or check existing modules in the repo for patterns — if similar programs already use `programs.*`, the new one likely does too.

## Task Routing

Match the user's intent to one of the tasks below. If unclear, ask.

| User says something like... | Task |
|---|---|
| "add ripgrep" / "install fd" / "I need Node.js" | **Add a Package** |
| "update my flake" / "update inputs" / "get latest nixpkgs" | **Update Flake Inputs** |
| "add a new module for ..." / "create a module" | **Add a New Module** |
| "configure git" / "set up zsh" / "enable fzf" | **Configure a Program** |
| "add my work laptop" / "set up a new machine" | **Add a Machine** |
| "add a flake input" / "I need sops-nix" / "add nix-index-database" | **Add a Flake Input** |
| "add a secret" / "store my API key" / "manage credentials" | **Manage Secrets** |
| "override X on my work machine" / "only on triangle" | **Add a Per-Machine Override** |
| "create a custom package" / "package my script" | **Add a Custom Package** |

## Tasks

### Add a Package

Determine the right method:

1. **`home.packages`** — for CLI tools from nixpkgs. Add to the appropriate module file (usually `modules/home/packages.nix` or a domain-specific module).

2. **`programs.*`** — if home-manager has a native module for the program, prefer this. It provides options for configuration, shell integration, etc. Check by searching for the program name in the existing modules. Common ones: `bat`, `fzf`, `jq`, `btop`, `zsh`, `git`, `direnv`, `emacs`, `neovim`, `kitty`, `starship`, `zoxide`, `eza`.

3. **Homebrew cask** — for macOS GUI apps that aren't in nixpkgs or work better as casks. Add to `homebrew.casks` in `modules/darwin/default.nix` or a host-specific config.

4. **Homebrew brew** — for macOS CLI tools that aren't in nixpkgs. Add to `homebrew.brews`.

5. **Flake input package** — for tools provided by external flakes. Access via `flake.inputs.<name>.packages.${pkgs.system}.<pkg>`.

When adding a package:
- If you're unsure of the exact package name, use `nix search nixpkgs --json <term>` to find it (see **Searching for Packages and Flakes** above)
- If the user names a binary rather than a package, use `nix-locate --whole-name bin/<name>` to find which package provides it
- Read the target file first to understand existing structure
- Add the package in alphabetical order within its group
- If the package needs a flake input that doesn't exist, do **Add a Flake Input** first

### Update Flake Inputs

Two options:

1. **Update all inputs**: Run `nix run .#update` (if the flake provides an update command) or `nix flake update`

2. **Update a specific input**: `nix flake update <input-name>` (e.g., `nix flake update nixpkgs`)

3. **Change an input URL**: Edit the `url` in `flake.nix` directly (e.g., to switch nixpkgs branches)

After updating, always run `nix flake check` to verify nothing broke.

### Add a New Module

1. **Decide scope**: Is this a home module (user-level) or system module (darwin/nixos)?

2. **Choose structure**:
   - **Simple module**: Create `modules/home/<name>.nix`
   - **Module with config files**: Create `modules/home/<name>/default.nix` plus config files in the same directory

3. **Write the module** following existing patterns:

   **Simple module:**
   ```nix
   { pkgs, ... }:
   {
     # packages, programs, home.file, etc.
   }
   ```

   **Option-driven module** (for complex, configurable features):
   ```nix
   { config, lib, pkgs, ... }:
   let cfg = config.<moduleName>; in
   {
     options.<moduleName> = {
       enable = lib.mkEnableOption "<description>";
       # additional options...
     };

     config = lib.mkIf cfg.enable {
       # actual configuration
     };
   }
   ```

4. **No import needed** for home modules — the auto-import in `modules/home/default.nix` picks up new files automatically.

5. For darwin or nixos modules, check if there's a similar auto-import pattern. If not, add the import manually.

### Configure a Program

1. **Check if home-manager has a module**: Look for `programs.<name>` options. If yes, prefer using it.

2. **Find or create the right module**: The program may already have a module file. Search `modules/home/` for it.

3. **Common patterns**:

   ```nix
   # Enable a program with home-manager
   programs.<name>.enable = true;

   # Set program-specific options
   programs.<name>.settings = { ... };

   # Manage a config file directly
   home.file.".config/<name>/config".source = ./<config-file>;
   # OR
   home.file.".config/<name>/config".text = ''
     config content here
   '';

   # Add shell aliases related to the program
   home.shellAliases = {
     alias = "command";
   };

   # Add shell integration
   programs.<name>.enableZshIntegration = true;
   ```

4. **For programs that need secrets**: Use `sops.templates` to generate config files with secret placeholders. See the claude-code module for a reference pattern.

### Add a Machine

1. **Determine type**: Darwin (macOS) or NixOS (Linux)?

2. **Get machine details**: hostname, architecture (e.g., `aarch64-darwin`, `x86_64-linux`), and what makes this machine different from existing ones.

3. **Create the configuration file**:

   **Darwin:**
   ```nix
   # configurations/darwin/<hostname>.nix
   { self, ... }:
   {
     imports = [ self.darwinModules.default ];

     nixpkgs.hostPlatform = "<arch>";
     networking.hostName = "<hostname>";

     # Machine-specific overrides go here
     home-manager.users.<username> = {
       # per-machine user config
     };
   }
   ```

   **NixOS:**
   ```nix
   # configurations/nixos/<hostname>.nix
   { self, ... }:
   {
     imports = [ self.nixosModules.default ];

     nixpkgs.hostPlatform = "<arch>";
     networking.hostName = "<hostname>";

     # Machine-specific config
   }
   ```

4. **If the machine needs secrets**: Generate an age key, add its public key to `.sops.yaml`, and re-encrypt secrets with `sops updatekeys secrets.yaml`.

5. The configuration is auto-discovered by nixos-unified — no manual registration in `flake.nix`.

### Add a Flake Input

**Preferred: Use `fh` (FlakeHub CLI)**

```bash
# Search for the flake
nix run nixpkgs#fh -- search <query>

# Add it to flake.nix (modifies the file and updates the lock)
nix run nixpkgs#fh -- add <owner>/<repo>
```

After `fh add`, review the generated input in `flake.nix` and:
- Add `inputs.nixpkgs.follows = "nixpkgs"` if `fh` didn't set it
- Verify the URL and version look correct

**Manual alternative** (if the flake isn't on FlakeHub):

1. **Add the input** to the `inputs` section of `flake.nix`:

   ```nix
   inputs = {
     # ...existing inputs...
     new-input.url = "github:owner/repo";
     new-input.inputs.nixpkgs.follows = "nixpkgs";  # if it takes nixpkgs
   };
   ```

2. **Add `follows`** for common dependencies to avoid duplicate nixpkgs evaluations. At minimum, follow `nixpkgs`. Check the input's `flake.nix` to see what inputs it accepts.

3. **Update the lock file**: Run `nix flake update <input-name>` to fetch it.

**Then for both methods**, if the flake provides a home-manager or darwin module, import it in the appropriate place:
- Home-manager module: import in a module file via `flake.inputs.<name>.homeManagerModules.<module>`
- Darwin module: import in `modules/darwin/default.nix` or the host config

### Manage Secrets

Prerequisites: `sops-nix` input and `sops.nix` home module must exist. Check for `.sops.yaml` and `secrets.yaml`.

1. **Add a new secret**:
   ```bash
   # Edit secrets file (decrypts, opens editor, re-encrypts)
   sops secrets.yaml
   ```
   Add the key-value pair in YAML format.

2. **Declare the secret** in a module or host config:
   ```nix
   sops.secrets.<secret_name> = {
     key = "SECRET_KEY_NAME";  # key in secrets.yaml
     mode = "0400";
   };
   ```

3. **Reference the secret**:
   - **In a template** (for config files mixing settings and secrets):
     ```nix
     sops.templates."<name>".content = builtins.toJSON {
       api_key = config.sops.placeholder.<secret_name>;
       other_setting = "value";
     };
     sops.templates."<name>".path = "${config.home.homeDirectory}/.config/<app>/config.json";
     ```
   - **As a file path** (for environment variables or file-based secrets):
     ```nix
     config.sops.secrets.<secret_name>.path
     ```

4. **For a new machine**: Generate an age key, add to `.sops.yaml`, re-encrypt:
   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt  # on the new machine
   # Add public key to .sops.yaml
   sops updatekeys secrets.yaml
   ```

### Add a Per-Machine Override

Per-machine overrides go in the host configuration file, inside a `home-manager.users.<username>` block:

```nix
# configurations/darwin/<hostname>.nix
home-manager.users.<username> = { lib, config, pkgs, ... }: {
  # Additional packages only on this machine
  home.packages = with pkgs; [ git-lfs ];

  # Override a module option
  someModule.someSetting = "machine-specific-value";

  # Additional Homebrew casks (darwin only — put outside home-manager block)
};
```

For darwin-level overrides (Homebrew, system defaults), put them at the top level of the host config, not inside `home-manager.users`.

Read the existing host configs to see the patterns in use.

### Add a Custom Package

1. **Create the package file** in `packages/<name>.nix`:

   **Shell wrapper:**
   ```nix
   { pkgs, ... }:
   pkgs.writeShellScriptBin "<name>" ''
     exec ${pkgs.<dependency>}/bin/<command> "$@"
   ''
   ```

   **Build from source:**
   ```nix
   { pkgs, ... }:
   pkgs.stdenv.mkDerivation {
     pname = "<name>";
     version = "<version>";
     src = pkgs.fetchFromGitHub {
       owner = "<owner>";
       repo = "<repo>";
       rev = "<tag-or-commit>";
       hash = "";  # nix will tell you the correct hash on first build
     };
     # buildInputs, buildPhase, installPhase, etc.
   }
   ```

2. **Import the package** where needed. Custom packages are NOT auto-imported. Add to a module:
   ```nix
   { pkgs, ... }:
   let
     myPkg = pkgs.callPackage ../../packages/<name>.nix { };
   in
   {
     home.packages = [ myPkg ];
   }
   ```

   Or if the package needs flake inputs, use the `flake` argument to pass them.

## Verification

After making any change, always verify:

1. **Format**: `nix fmt` — fixes formatting issues
2. **Check**: `nix flake check` — catches evaluation errors
3. **Activate**: `nix run .#activate` — applies the configuration

If `nix flake check` fails, read the error carefully:
- **Infinite recursion**: Usually a circular import or self-referencing option
- **Attribute not found**: Missing input, wrong package name, or missing `follows`
- **Type mismatch**: Option value doesn't match declared type

## Reference Patterns

### Auto-Import Convention

Files in `modules/home/` are auto-imported. Both patterns work:
- `modules/home/foo.nix` — single-file module
- `modules/home/foo/default.nix` — module with auxiliary files

### Accessing Flake Inputs in Modules

```nix
{ flake, pkgs, ... }:
let inherit (flake) inputs; in
{
  home.packages = [
    inputs.some-input.packages.${pkgs.system}.default
  ];
}
```

### Configuration Hierarchy

```
flake.nix                              -> inputs and auto-discovery
modules/home/                          -> shared home modules (all users, all machines)
modules/darwin/                        -> shared darwin system config
modules/nixos/                         -> shared nixos system config
configurations/home/<user>.nix         -> user identity and stateVersion
configurations/darwin/<host>.nix       -> host-specific darwin config + overrides
configurations/nixos/<host>.nix        -> host-specific nixos config + overrides
```

Overrides flow downward: host configs can override anything from shared modules via `home-manager.users.<name>` blocks.

### Common Commands

```bash
nix run .#activate                    # Apply configuration
nix run .#update                      # Update all flake inputs
nix flake update <name>               # Update a specific input
nix fmt                               # Format all .nix files
nix flake check                       # Verify evaluation
nix flake show                        # Show all outputs
sops secrets.yaml                     # Edit encrypted secrets
nix search nixpkgs --json <term>      # Search for packages
nix-locate --whole-name bin/<name>    # Find package by binary name
nix run nixpkgs#fh -- search <query>  # Search for flakes on FlakeHub
nix run nixpkgs#fh -- add <ref>       # Add a flake input via FlakeHub
```
