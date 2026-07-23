#!/usr/bin/env bash
# Bump packages/fx.nix to the latest (or a given) fx CLI release from the CDN.
set -euo pipefail

CDN="${FX_CDN:-https://ugiwefobuo4tac0m.public.blob.vercel-storage.com/cli}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FX_NIX="${FX_NIX:-$ROOT/packages/fx.nix}"

PLATFORMS=(
  aarch64-darwin:macos-aarch64
  x86_64-darwin:macos-x86_64
  aarch64-linux:linux-aarch64
  x86_64-linux:linux-x86_64
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

if [[ ! -f "$FX_NIX" ]]; then
  echo "error: fx package not found: $FX_NIX" >&2
  exit 1
fi

fetch_latest() {
  curl -fsSL "${CDN}/latest.txt" | tr -d '[:space:]'
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
  python3 - "$FX_NIX" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'version\s*=\s*"([^"]+)"', text)
if not m:
    sys.exit("could not find version in fx.nix")
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

write_fx_nix() {
  local version="$1"
  shift
  # remaining args: nixSystem=sriHash pairs in PLATFORMS order
  python3 - "$FX_NIX" "$version" "$@" <<'PY'
import pathlib, re, sys

path = pathlib.Path(sys.argv[1])
version = sys.argv[2]
hashes = dict(arg.split("=", 1) for arg in sys.argv[3:])

text = path.read_text(encoding="utf-8")

def replace_version(match: re.Match[str]) -> str:
    return f'{match.group(1)}"{version}"'

text, n = re.subn(
    r'(version\s*=\s*)"[^"]*"',
    replace_version,
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
  local raw latest version current
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
    echo "already at $version ($FX_NIX)"
    exit 0
  fi

  echo "bumping fx: $current -> $version"

  for entry in "${PLATFORMS[@]}"; do
    system="${entry%%:*}"
    asset="${entry##*:}"
    url="${CDN}/v${version}/fx-${asset}.tar.gz"
    echo "prefetch ${asset}..."
    sri="$(sri_hash "$url")"
    hash_args+=("${system}=${sri}")
  done

  write_fx_nix "$version" "${hash_args[@]}"
}

main "$@"
