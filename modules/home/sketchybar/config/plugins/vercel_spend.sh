#!/bin/sh

# Today's AI Gateway spend for the user authenticated with the Vercel CLI.
# The popup shows the five highest-cost models and keeps the last good report
# visible (marked stale) when Vercel cannot be reached.

VERCEL="${VERCEL:-$(command -v vercel 2>/dev/null || echo /opt/homebrew/bin/vercel)}"
JQ="${JQ:-$(command -v jq 2>/dev/null || echo "/etc/profiles/per-user/$(id -un)/bin/jq")}"
TEAM_ID="${VERCEL_AI_GATEWAY_TEAM_ID:-team_TtmJZYmD3tcLBLqWOhoVawd1}"
CACHE="${TMPDIR:-/tmp}/sketchybar-vercel-spend.json"
STAMP="${TMPDIR:-/tmp}/sketchybar-vercel-spend.timestamp"
today="$(/bin/date +%Y-%m-%d)"

report="$(NO_UPDATE_NOTIFIER=1 VERCEL_FORCE_NO_UPDATE_NOTIFIER=1 \
  "$VERCEL" --api https://ai-gateway.vercel.sh api \
  "/v1/report?start_date=$today&end_date=$today&group_by=model&metered_scope=user" \
  -H "x-vercel-ai-gateway-team: $TEAM_ID" --raw --non-interactive 2>/dev/null)"

if printf '%s' "$report" | "$JQ" -e '.results | arrays' >/dev/null 2>&1; then
  printf '%s\n' "$report" > "$CACHE"
  /bin/date +%s > "$STAMP"
  status="Today · updated $(/bin/date '+%-I:%M %p')"
  stale=false
else
  report="$(cat "$CACHE" 2>/dev/null)"
  if [ -n "$report" ] && [ -r "$STAMP" ]; then
    updated="$(/bin/date -r "$(cat "$STAMP")" '+%-I:%M %p' 2>/dev/null)"
    status="Offline · showing data from ${updated:-an earlier update}"
  else
    status="Offline · no cached usage"
  fi
  stale=true
fi

spend="$(printf '%s' "$report" | "$JQ" -r '[.results[]?.total_cost // 0] | add // 0' 2>/dev/null)"
label="$(awk -v dollars="${spend:-0}" 'BEGIN { printf "$%.2f", dollars }')"

if [ "$stale" = true ]; then
  sketchybar --set "$NAME" icon="▲!" label="$label"
else
  sketchybar --set "$NAME" icon="▲" label="$label"
fi

sketchybar --set vercel_spend.status label="$status"

rows="$(printf '%s' "$report" | "$JQ" -r '
  def tokens:
    if . >= 1000000000 then "\(. / 1000000000 * 10 | round / 10)B"
    elif . >= 1000000 then "\(. / 1000000 * 10 | round / 10)M"
    elif . >= 1000 then "\(. / 1000 * 10 | round / 10)K"
    else "\(.)"
    end;
  [.results[]?]
  | sort_by(-(.total_cost // 0))
  | .[:5][]
  | "\(.model)  ·  \((.input_tokens + .output_tokens + .cached_input_tokens) | tokens) tok  ·  \((.cache_hit_pct // 0) | round)% cache  ·  $\((.total_cost // 0) * 100 | round / 100)"
' 2>/dev/null)"

row=1
if [ -z "$rows" ]; then
  sketchybar --set vercel_spend.model.1 drawing=on label="No model usage yet today"
  row=2
fi

while IFS= read -r text; do
  [ -n "$text" ] || continue
  sketchybar --set "vercel_spend.model.$row" drawing=on label="$text"
  row=$((row + 1))
done <<EOF
$rows
EOF

while [ "$row" -le 5 ]; do
  sketchybar --set "vercel_spend.model.$row" drawing=off
  row=$((row + 1))
done
