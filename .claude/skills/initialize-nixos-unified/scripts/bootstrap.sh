#!/usr/bin/env bash
# Bootstrap a new nixos-unified dotfiles repo from the official template.
# Usage: bootstrap.sh <template> <output-dir>
#   template: linux | macos | home
#   output-dir: path to create the new repo (e.g., ~/dotfiles)
set -euo pipefail

TEMPLATE="${1:?Usage: bootstrap.sh <linux|macos|home> <output-dir>}"
OUTPUT_DIR="${2:?Usage: bootstrap.sh <linux|macos|home> <output-dir>}"

if [[ "$TEMPLATE" != "linux" && "$TEMPLATE" != "macos" && "$TEMPLATE" != "home" ]]; then
  echo "Error: template must be one of: linux, macos, home" >&2
  exit 1
fi

if [[ -d "$OUTPUT_DIR" && "$(ls -A "$OUTPUT_DIR" 2>/dev/null)" ]]; then
  echo "Error: $OUTPUT_DIR already exists and is not empty" >&2
  exit 1
fi

echo "Bootstrapping nixos-unified '$TEMPLATE' template into $OUTPUT_DIR..."
nix --accept-flake-config run github:juspay/omnix -- \
  init -o "$OUTPUT_DIR" "github:srid/nixos-unified#${TEMPLATE}"

echo ""
echo "Template created at $OUTPUT_DIR"
echo "Next steps:"
echo "  cd $OUTPUT_DIR"
echo "  git init && git add -A"
echo "  # Edit configurations and modules, then:"
echo "  nix run .#activate"
