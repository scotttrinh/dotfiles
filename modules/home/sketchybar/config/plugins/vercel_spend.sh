#!/bin/sh

# AI Gateway spend for the user authenticated with the Vercel CLI.
# Supports switching between periods: today, this calendar week,
# month to date, and last month. The popup shows the five highest-cost
# models for the selected period and keeps the last good report visible
# (marked stale) when Vercel cannot be reached.

VERCEL="${VERCEL:-$(command -v vercel 2>/dev/null || echo /opt/homebrew/bin/vercel)}"
JQ="${JQ:-$(command -v jq 2>/dev/null || echo "/etc/profiles/per-user/$(id -un)/bin/jq")}"
TEAM_ID="${VERCEL_AI_GATEWAY_TEAM_ID:-team_TtmJZYmD3tcLBLqWOhoVawd1}"
NAME="${NAME:-vercel_spend}"

if [ -n "$CONFIG_DIR" ] && [ -r "$CONFIG_DIR/colors.sh" ]; then
  . "$CONFIG_DIR/colors.sh"
else
  ACCENT_COLOR="${ACCENT_COLOR:-0xffa7c7e7}"
  MUTED_COLOR="${MUTED_COLOR:-0xffa1a7b3}"
fi

PERIOD_FILE="${TMPDIR:-/tmp}/sketchybar-vercel-spend.period"

case "$1" in
  today|week|month|last_month)
    period="$1"
    printf '%s\n' "$period" > "$PERIOD_FILE"
    ;;
  *)
    period="$(cat "$PERIOD_FILE" 2>/dev/null)"
    case "$period" in
      today|week|month|last_month) ;;
      *) period="today" ;;
    esac
    ;;
esac

today="$(/bin/date +%Y-%m-%d)"

case "$period" in
  week)
    start_date="$(/bin/date -v-monday +%Y-%m-%d)"
    end_date="$today"
    period_label="This calendar week"
    refresh_msg="Refreshing this calendar week…"
    empty_msg="No model usage this week"
    ;;
  month)
    start_date="$(/bin/date -v1d +%Y-%m-%d)"
    end_date="$today"
    period_label="Month to date"
    refresh_msg="Refreshing month to date…"
    empty_msg="No model usage this month"
    ;;
  last_month)
    start_date="$(/bin/date -v1d -v-1m +%Y-%m-%d)"
    end_date="$(/bin/date -v1d -v-1d +%Y-%m-%d)"
    period_label="Last month"
    refresh_msg="Refreshing last month…"
    empty_msg="No model usage last month"
    ;;
  today|*)
    start_date="$today"
    end_date="$today"
    period_label="Today"
    refresh_msg="Refreshing today…"
    empty_msg="No model usage yet today"
    ;;
esac

# Immediately update period radio buttons and status
sketchybar \
  --set vercel_spend.status label="$refresh_msg" \
  --set vercel_spend.period.today \
    icon="$([ "$period" = today ] && echo "●" || echo "○")" \
    icon.color="$([ "$period" = today ] && echo "$ACCENT_COLOR" || echo "$MUTED_COLOR")" \
    label.color="$([ "$period" = today ] && echo "$ACCENT_COLOR" || echo "$MUTED_COLOR")" \
  --set vercel_spend.period.week \
    icon="$([ "$period" = week ] && echo "●" || echo "○")" \
    icon.color="$([ "$period" = week ] && echo "$ACCENT_COLOR" || echo "$MUTED_COLOR")" \
    label.color="$([ "$period" = week ] && echo "$ACCENT_COLOR" || echo "$MUTED_COLOR")" \
  --set vercel_spend.period.month \
    icon="$([ "$period" = month ] && echo "●" || echo "○")" \
    icon.color="$([ "$period" = month ] && echo "$ACCENT_COLOR" || echo "$MUTED_COLOR")" \
    label.color="$([ "$period" = month ] && echo "$ACCENT_COLOR" || echo "$MUTED_COLOR")" \
  --set vercel_spend.period.last_month \
    icon="$([ "$period" = last_month ] && echo "●" || echo "○")" \
    icon.color="$([ "$period" = last_month ] && echo "$ACCENT_COLOR" || echo "$MUTED_COLOR")" \
    label.color="$([ "$period" = last_month ] && echo "$ACCENT_COLOR" || echo "$MUTED_COLOR")"

CACHE="${TMPDIR:-/tmp}/sketchybar-vercel-spend-${period}.json"
STAMP="${TMPDIR:-/tmp}/sketchybar-vercel-spend-${period}.timestamp"

# Backwards compatibility with single cache file
if [ "$period" = "today" ] && [ ! -r "$CACHE" ] && [ -r "${TMPDIR:-/tmp}/sketchybar-vercel-spend.json" ]; then
  CACHE="${TMPDIR:-/tmp}/sketchybar-vercel-spend.json"
  STAMP="${TMPDIR:-/tmp}/sketchybar-vercel-spend.timestamp"
fi

report="$(NO_UPDATE_NOTIFIER=1 VERCEL_FORCE_NO_UPDATE_NOTIFIER=1 \
  "$VERCEL" --api https://ai-gateway.vercel.sh api \
  "/v1/report?start_date=$start_date&end_date=$end_date&group_by=model&metered_scope=user" \
  -H "x-vercel-ai-gateway-team: $TEAM_ID" --raw --non-interactive 2>/dev/null)"

# If another period was selected while this request was in flight, abort so we don't overwrite
current_period="$(cat "$PERIOD_FILE" 2>/dev/null)"
if [ -n "$current_period" ] && [ "$current_period" != "$period" ]; then
  exit 0
fi

if printf '%s' "$report" | "$JQ" -e '.results | arrays' >/dev/null 2>&1; then
  printf '%s\n' "$report" > "$CACHE"
  /bin/date +%s > "$STAMP"
  status="$period_label · updated $(/bin/date '+%-I:%M %p')"
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
  sketchybar --set vercel_spend.model.1 drawing=on label="$empty_msg"
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
