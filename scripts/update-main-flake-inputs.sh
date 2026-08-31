set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

nix flake update nixpkgs home-manager nix-darwin
bash "$root/scripts/refresh-package-versions.sh"
