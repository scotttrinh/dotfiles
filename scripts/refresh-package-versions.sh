set -euo pipefail

root="$(git rev-parse --show-toplevel)"
host="${PACKAGE_HOST:-$(hostname -s)}"
manifest="$root/package-versions.json"
runtime_manifest="${XDG_STATE_HOME:-$HOME/.local/state}/selected-packages.json"
versions_expression="$root/scripts/selected-package-versions.nix"

evaluate() {
  PACKAGE_HOST="$host" nix eval --json --impure --file "$versions_expression"
}

print_changes() {
  local heading="$1"
  local before="$2"
  local after="$3"
  local changed=0

  echo "$heading"
  while IFS= read -r package; do
    old="$(jq -r --arg package "$package" '.[$package] // "missing" | if type == "object" then (.version // "unknown") else . end' <<<"$before")"
    new="$(jq -r --arg package "$package" '.[$package] // "missing" | if type == "object" then (.version // "unknown") else . end' <<<"$after")"
    if [[ "$old" != "$new" ]]; then
      printf '  %-28s %s -> %s\n' "$package" "$old" "$new"
      changed=1
    fi
  done < <(jq -r -s '.[0] + .[1] | keys[]' <<<"$before $after")

  if [[ "$changed" -eq 0 ]]; then
    echo "  No package versions changed."
  fi
}

cd "$root"
after="$(evaluate)"

if [[ -f "$manifest" ]]; then
  tracked_all="$(cat "$manifest")"
  tracked="$(jq -c --arg host "$host" '.[$host] // {}' <<<"$tracked_all")"
else
  tracked_all='{}'
  tracked='{}'
fi

print_changes "Selected packages changed in evaluated configuration:" "$tracked" "$after"
printf '%s\n' "$tracked_all" | jq --arg host "$host" --argjson packages "$after" '.[$host] = $packages' | jq --sort-keys . > "$manifest"

echo
if [[ -f "$runtime_manifest" ]]; then
  runtime="$(cat "$runtime_manifest")"
  print_changes "Selected packages that will change on next activation:" "$runtime" "$after"
else
  echo "Runtime package versions unavailable until the next activation creates:"
  echo "  $runtime_manifest"
fi

echo
echo "Updated package-versions.json for $host."
