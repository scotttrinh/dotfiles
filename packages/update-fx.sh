#!/usr/bin/env bash
# Bump packages/fx.nix to the latest successfully published fx dev build.
set -euo pipefail

CDN="${FX_CDN:-https://releases.fx.sh}"
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

fetch_target() {
  curl -fsSL "${CDN}/dev.json" |
    python3 -c '
import json, re, sys
manifest = json.load(sys.stdin)
version = manifest.get("version", "")
revision = manifest.get("commit", "")
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
    sys.exit("invalid version in dev manifest")
if not re.fullmatch(r"[0-9a-fA-F]{7,64}", revision):
    sys.exit("invalid commit in dev manifest")
print(version, revision)
'
}

current_revision() {
  python3 - "$FX_NIX" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'rev\s*=\s*"([^"]+)"', text)
if not m:
    sys.exit("could not find rev in fx.nix")
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
  local revision="$2"
  shift 2
  # remaining args: nixSystem=sriHash pairs in PLATFORMS order
  python3 - "$FX_NIX" "$version" "$revision" "$@" <<'PY'
import pathlib, re, sys

path = pathlib.Path(sys.argv[1])
version = sys.argv[2]
revision = sys.argv[3]
hashes = dict(arg.split("=", 1) for arg in sys.argv[4:])

text = path.read_text(encoding="utf-8")

for field, value in (("version", version), ("rev", revision)):
    text, n = re.subn(
        rf'({field}\s*=\s*)"[^"]*"',
        lambda match, value=value: f'{match.group(1)}"{value}"',
        text,
        count=1,
    )
    if n != 1:
        sys.exit(f"could not update {field} field")

for system, sri in hashes.items():
    pattern = rf'({re.escape(system)}\s*=\s*\{{\s*name\s*=\s*"[^"]+";\s*hash\s*=\s*)"sha256-[^"]+"'
    text, n = re.subn(pattern, rf'\1"{sri}"', text, count=1)
    if n != 1:
        sys.exit(f"could not update hash for {system}")

path.write_text(text, encoding="utf-8")
print(f"updated {path} -> dev {revision} ({version})")
for system, sri in hashes.items():
    print(f"  {system}: {sri}")
PY
}

main() {
  local target version revision current
  local -a hash_args=()
  local entry system asset url sri

  if [[ $# -ne 0 ]]; then
    echo "usage: $0" >&2
    echo "The dev target is resolved from ${CDN}/dev.json." >&2
    exit 2
  fi

  target="$(fetch_target)"
  read -r version revision <<<"$target"
  current="$(current_revision)"

  if [[ "$revision" == "$current" && -z "${FORCE:-}" ]]; then
    echo "already at dev $revision ($FX_NIX)"
    exit 0
  fi

  echo "bumping fx dev: $current -> $revision ($version)"

  for entry in "${PLATFORMS[@]}"; do
    system="${entry%%:*}"
    asset="${entry##*:}"
    url="${CDN}/dev/${revision}/fx-${asset}.tar.gz"
    echo "prefetch ${asset}..."
    sri="$(sri_hash "$url")"
    hash_args+=("${system}=${sri}")
  done

  write_fx_nix "$version" "$revision" "${hash_args[@]}"
}

main "$@"
