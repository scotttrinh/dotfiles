#!/usr/bin/env bash
# Bump packages/devbox.nix to the latest (or a given) devbox CLI build.
#
# The upstream installer (https://api.vercel.com/v1/devbox/install.sh) always
# pulls a rolling "latest" object from S3:
#   https://devboxd.s3.us-west-1.amazonaws.com/devbox-<os>-<arch>
# which is not content-addressable. The same bucket also serves immutable,
# commit-pinned copies:
#   https://devboxd.s3.us-west-1.amazonaws.com/devbox-<os>-<arch>-<commit12>
# so this script resolves the current rolling build's commit (from the Go
# build info embedded in the binary) and pins that.
set -euo pipefail

BUCKET="${DEVBOX_BUCKET:-https://devboxd.s3.us-west-1.amazonaws.com}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVBOX_NIX="${DEVBOX_NIX:-$ROOT/packages/devbox.nix}"

PLATFORMS=(
  aarch64-darwin:darwin-arm64
  x86_64-darwin:darwin-amd64
  aarch64-linux:linux-arm64
  x86_64-linux:linux-amd64
)

# Platform used to sniff the rolling build's commit SHA.
PROBE_ASSET="${DEVBOX_PROBE_ASSET:-darwin-arm64}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    exit 1
  }
}

need curl
need nix
need python3

if [[ ! -f "$DEVBOX_NIX" ]]; then
  echo "error: devbox package not found: $DEVBOX_NIX" >&2
  exit 1
fi

fetch_latest_commit() {
  local tmp rev
  tmp="$(mktemp -t devbox-probe)"
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" RETURN
  curl -fsSL --retry 3 --retry-delay 1 -o "$tmp" "${BUCKET}/devbox-${PROBE_ASSET}" ||
    {
      echo "error: failed to download ${BUCKET}/devbox-${PROBE_ASSET}" >&2
      exit 1
    }
  rev="$(LC_ALL=C grep -ao 'vcs\.revision=[0-9a-f]\{40\}' "$tmp" | head -1 || true)"
  rev="${rev#vcs.revision=}"
  if [[ -z "$rev" ]]; then
    echo "error: could not read vcs.revision from rolling devbox binary" >&2
    exit 1
  fi
  echo "${rev:0:12}"
}

normalize_version() {
  local raw="$1"
  raw="${raw#v}"
  if [[ ! "$raw" =~ ^[0-9a-f]{12}$ ]]; then
    echo "error: invalid devbox commit (want 12 hex chars): $1" >&2
    exit 1
  fi
  echo "$raw"
}

current_version() {
  python3 - "$DEVBOX_NIX" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'version\s*=\s*"([^"]+)"', text)
if not m:
    sys.exit("could not find version in devbox.nix")
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

write_devbox_nix() {
  local version="$1"
  shift
  # remaining args: nixSystem=sriHash pairs in PLATFORMS order
  python3 - "$DEVBOX_NIX" "$version" "$@" <<'PY'
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
  local raw version current
  local -a hash_args=()
  local entry system asset url sri

  if [[ -n "$requested" ]]; then
    raw="$requested"
  else
    echo "resolving latest devbox commit..."
    raw="$(fetch_latest_commit)"
  fi

  version="$(normalize_version "$raw")"
  current="$(current_version)"

  if [[ "$version" == "$current" && -z "${FORCE:-}" ]]; then
    echo "already at $version ($DEVBOX_NIX)"
    exit 0
  fi

  echo "bumping devbox: $current -> $version"

  for entry in "${PLATFORMS[@]}"; do
    system="${entry%%:*}"
    asset="${entry##*:}"
    url="${BUCKET}/devbox-${asset}-${version}"
    echo "prefetch ${asset}..."
    sri="$(sri_hash "$url")"
    hash_args+=("${system}=${sri}")
  done

  write_devbox_nix "$version" "${hash_args[@]}"
}

main "$@"
