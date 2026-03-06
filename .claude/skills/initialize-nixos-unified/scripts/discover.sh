#!/usr/bin/env bash
# Detect the user's environment for bootstrapping a nixos-unified dotfiles repo.
set -euo pipefail

echo "=== System ==="
echo "os: $(uname -s)"
echo "arch: $(uname -m)"
echo "username: $(id -un)"
echo "hostname: $(scutil --get LocalHostName 2>/dev/null || hostname -s)"

echo ""
echo "=== Nix ==="
if command -v nix &>/dev/null; then
  echo "nix: $(which nix)"
  echo "nix-version: $(nix --version 2>/dev/null || echo unknown)"
else
  echo "nix: NOT INSTALLED"
fi

echo ""
echo "=== Homebrew ==="
if command -v brew &>/dev/null; then
  echo "brew: $(which brew)"
  echo "casks:"
  brew list --cask 2>/dev/null | sed 's/^/  - /' || echo "  (none)"
else
  echo "brew: NOT INSTALLED"
fi

echo ""
echo "=== Terminals ==="
for t in ghostty kitty alacritty wezterm iterm2; do
  if command -v "$t" &>/dev/null; then
    echo "$t: $(which "$t")"
  fi
done

echo ""
echo "=== Editors ==="
for e in emacs nvim vim code cursor; do
  if command -v "$e" &>/dev/null; then
    echo "$e: $(which "$e")"
  fi
done

echo ""
echo "=== Languages ==="
for l in node python3 rustc go java ruby; do
  if command -v "$l" &>/dev/null; then
    echo "$l: $(which "$l")"
  fi
done

echo ""
echo "=== Shell ==="
echo "current: $SHELL"
