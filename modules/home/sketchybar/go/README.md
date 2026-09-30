# Go plugins for SketchyBar

This directory is a Go module inside the dotfiles repo. It builds one command, `sketchybar-plugins`. For now, the command accepts only `probe`; the clock and other existing plugins still use shell scripts.

## Run the probe locally

The Home Manager package list in `modules/home/packages.nix` includes Go. If you have not activated that change, start a temporary shell with `nix shell nixpkgs#go` first.

From the repository root:

```sh
cd modules/home/sketchybar/go
go test ./...
go run . probe
```

Without SketchyBar's `NAME` environment variable, the probe prints `Go plugin ready`. Other arguments print usage and exit with status 2. `go run` is useful for development, but it compiles before each run. SketchyBar runs a binary instead.

## Try edits in the bar

Build a development binary in your home directory:

```sh
cd modules/home/sketchybar/go
mkdir -p "$HOME/.local/bin"
go build -o "$HOME/.local/bin/sketchybar-plugins" .
"$HOME/.local/bin/sketchybar-plugins" probe
sketchybar --update
```

The `go_probe` item in `../config/sketchybarrc` starts with the label `Loading`. When SketchyBar runs the probe, it passes `NAME=go_probe`. The Go code calls `sketchybar --set go_probe label=Go works`. Run `sketchybar --update` after each rebuild to refresh the item. You do not need a Nix activation for each Go edit, but you do need to activate the configuration once to install the item and its wrapper.

The generated `go_probe.sh` wrapper prefers the executable at `$HOME/.local/bin/sketchybar-plugins`. If that file does not exist or is not executable, the wrapper runs the Nix-built binary. To switch back to the installed version, remove the development binary and update the bar:

```sh
rm "$HOME/.local/bin/sketchybar-plugins"
sketchybar --update
```

An old development binary takes precedence even after a new Nix activation. If the bar does not reflect a deployed change, check that path first. SketchyBar's launch agent may have a different `PATH` from your terminal; the wrapper uses absolute paths for both binaries. The Go probe currently invokes `sketchybar` by name, like the existing shell plugins, so that command must still be available to the launch agent.

## Install the Nix-built version

`package.nix` uses `buildGoModule` on this directory. `../default.nix` installs the package through `selectedPackages`, generates the wrapper alongside the existing config, and restarts SketchyBar on activation. Because the directory is named `go`, the package renames Go's default `go` executable output to `sketchybar-plugins` after the build.

From the repository root, stage new source files so the Git-backed flake includes them, then activate:

```sh
git add modules/home/sketchybar/go
nix run .#activate
```

Run `go test ./...` from `modules/home/sketchybar/go` before activation. Staging is enough for Nix to see new files; you do not need to commit before activation. Activation builds the installed executable and config, then restarts SketchyBar. Do not edit the generated files in the Nix store or under `~/.config/sketchybar`.

## Add dependencies or another plugin

Use normal Go module commands inside this directory:

```sh
cd modules/home/sketchybar/go
go get example.com/some/module
go mod tidy
go test ./...
```

Commit both `go.mod` and `go.sum` when `go.sum` appears. The current `vendorHash = null` in `package.nix` works because the module has no external dependencies. After adding dependencies, set `vendorHash` to a temporary incorrect hash, run the Nix build, and replace it with the hash from Nix's mismatch error. Nix then fetches those exact module dependencies during its build. Do not rely on the Go download cache from your development shell for the Nix build.

To add a plugin, give `main.go` another command case, implement it in this module, and register a SketchyBar item in `../config/sketchybarrc`. Add a wrapper in `../default.nix` that passes the new command name to the binary. `probe.go` shows how to use SketchyBar's `NAME` environment variable and update the calling item.

This is otherwise a regular Go module: `go.mod` defines its module path and minimum Go version, and `go test` and `go build` work from this directory. What is specific to this repo is the Nix package, the generated wrapper, and the choice between a local development binary and a reproducible installed binary. No Go compiler runs on each SketchyBar update.
