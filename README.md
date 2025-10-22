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

## Linux Notes

The tree currently doesn't include a NixOS host, but nixos-unified supports it.
To add one:

1. Create `configurations/nixos/<hostname>.nix` and import
   `self.nixosModules.default` just like the macOS examples.
2. Define `nixpkgs.hostPlatform = "x86_64-linux"` (or `aarch64-linux`) and any
   NixOS-specific settings.
3. On the target machine, boot into the installer, clone this repo, and run:
   ```sh
   sudo nixos-rebuild switch --flake .#<hostname>
   ```
   or follow the [`nixos-unified` installation guide](https://nixos-unified.org)
   for its streamlined `nix run .#activate` workflow on NixOS.

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

