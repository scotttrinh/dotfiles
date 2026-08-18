#!/usr/bin/env bash
# Bump packages/ty.nix to the latest (or a given) ty release from GitHub.
#
# ty is packaged from Astral's prebuilt release tarballs (one per platform),
# so this just prefetches each asset and rewrites the version + hashes.
set -euo pipefail

REPO="${TY_REPO:-astral-sh/ty}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TY_NIX="${TY_NIX:-$ROOT/packages/ty.nix}"

# nixSystem:releaseAsset pairs. Linux uses the static musl builds so the same
# package runs on NixOS without patchelf.
PLATFORMS=(
  aarch64-darwin:aarch64-apple-darwin
  x86_64-darwin:x86_64-apple-darwin
  aarch64-linux:aarch64-unknown-linux-musl
  x86_64-linux:x86_64-unknown-linux-musl
)

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    exit 1
  }
}

need curl
need nix
need python3

if [[ ! -f "$TY_NIX" ]]; then
  echo "error: ty package not found: $TY_NIX" >&2
  exit 1
fi

fetch_latest() {
  curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" |
    python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])'
}

normalize_version() {
  local raw="$1"
  raw="${raw#v}"
  if [[ -z "$raw" || ! "$raw" =~ ^[0-9] ]]; then
    echo "error: invalid version: $1" >&2
    exit 1
  fi
  echo "$raw"
}

current_version() {
  python3 - "$TY_NIX" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'version\s*=\s*"([^"]+)"', text)
if not m:
    sys.exit("could not find version in ty.nix")
print(m.group(1))
PY
}

sri_hash() {
  local url="$1"
  local nar
  nar="$(nix-prefetch-url "$url" 2>/dev/null | tail -1)"
  if [[ -z "$nar" ]]; then
    echo "error: failed to prefetch $url" >&2
    exit 1
  fi
  if nix hash convert --help >/dev/null 2>&1; then
    nix hash convert --hash-algo sha256 --to sri "$nar"
  else
    nix hash to-sri --type sha256 "$nar"
  fi
}

write_ty_nix() {
  local version="$1"
  shift
  # remaining args: nixSystem=sriHash pairs in PLATFORMS order
  python3 - "$TY_NIX" "$version" "$@" <<'PY'
import pathlib, re, sys

path = pathlib.Path(sys.argv[1])
version = sys.argv[2]
hashes = dict(arg.split("=", 1) for arg in sys.argv[3:])

text = path.read_text(encoding="utf-8")

text, n = re.subn(
    r'(version\s*=\s*)"[^"]*"',
    rf'\1"{version}"',
    text,
    count=1,
)
if n != 1:
    sys.exit("could not update version field")

for system, sri in hashes.items():
    pattern = rf'({re.escape(system)}\s*=\s*\{{\s*name\s*=\s*"[^"]+";\s*hash\s*=\s*)"sha256-[^"]+"'
    text, n = re.subn(pattern, rf'\1"{sri}"', text, count=1)
    if n != 1:
        sys.exit(f"could not update hash for {system}")

path.write_text(text, encoding="utf-8")
print(f"updated {path} -> {version}")
for system, sri in hashes.items():
    print(f"  {system}: {sri}")
PY
}

main() {
  local requested="${1:-}"
  local raw version current
  local -a hash_args=()
  local entry system asset url sri

  if [[ -n "$requested" ]]; then
    raw="$requested"
  else
    raw="$(fetch_latest)"
  fi

  version="$(normalize_version "$raw")"
  current="$(current_version)"

  if [[ "$version" == "$current" && -z "${FORCE:-}" ]]; then
    echo "already at $version ($TY_NIX)"
    exit 0
  fi

  echo "bumping ty: $current -> $version"

  for entry in "${PLATFORMS[@]}"; do
    system="${entry%%:*}"
    asset="${entry##*:}"
    url="https://github.com/${REPO}/releases/download/${version}/ty-${asset}.tar.gz"
    echo "prefetch ${asset}..."
    sri="$(sri_hash "$url")"
    hash_args+=("${system}=${sri}")
  done

  write_ty_nix "$version" "${hash_args[@]}"

  echo "building..."
  (cd "$ROOT" && nix build .#ty && ./result/bin/ty --version)
}

main "$@"
