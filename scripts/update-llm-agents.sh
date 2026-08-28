set -euo pipefail

root="$(git rev-parse --show-toplevel)"
manifest="$root/llm-agents-versions.json"
runtime_manifest="${XDG_STATE_HOME:-$HOME/.local/state}/llm-agents/versions.json"
versions_expression="$root/scripts/llm-agents-versions.nix"

evaluate() {
  nix eval --json --impure --file "$versions_expression"
}

print_changes() {
  local heading="$1"
  local before="$2"
  local after="$3"
  local changed=0

  echo "$heading"
  while IFS= read -r package; do
    old="$(jq -r --arg package "$package" '.packages[$package] // "missing"' <<<"$before")"
    new="$(jq -r --arg package "$package" '.packages[$package] // "missing"' <<<"$after")"
    if [[ "$old" != "$new" ]]; then
      printf '  %-20s %s -> %s\n' "$package" "$old" "$new"
      changed=1
    fi
  done < <(jq -r -s '.[0].packages + .[1].packages | keys[]' <<<"$before $after")

  if [[ "$changed" -eq 0 ]]; then
    echo "  No package versions changed."
  fi
}

cd "$root"

if [[ -f "$manifest" ]]; then
  locked_before="$(cat "$manifest")"
else
  locked_before="$(evaluate)"
fi

nix flake update llm-agents
locked_after="$(evaluate)"
printf '%s\n' "$locked_after" | jq --sort-keys . > "$manifest"

echo
printf 'Lock update %s -> %s\n' \
  "$(jq -r .revision <<<"$locked_before")" \
  "$(jq -r .revision <<<"$locked_after")"
print_changes "Packages changed in lock file:" "$locked_before" "$locked_after"

echo
if [[ -f "$runtime_manifest" ]]; then
  runtime="$(cat "$runtime_manifest")"
  print_changes "Packages that will change on next activation:" "$runtime" "$locked_after"
else
  echo "Runtime package versions unavailable until the next activation creates:"
  echo "  $runtime_manifest"
fi

echo
echo "Updated llm-agents-versions.json; include it with flake.lock in the bump commit."
