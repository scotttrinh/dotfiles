#!/bin/sh

# Clock + next upcoming (or running) meeting, read from the macOS Calendar via
# acal. One-time setup: `acal auth grant` (Calendar full access).
#
# acal 0.3.0 crashes ("Duplicate values for key") when a query range contains
# two occurrences of the same recurring event, so query one local day at a
# time and stop at the first day that has an upcoming event. If upstream
# fixes the dictionary crash, the loop can collapse into a single query.
#
# The event is cached until it ends (or, if there is nothing upcoming, for two
# minutes) so the clock can keep ticking every 10 seconds without re-querying
# EventKit.
#
# Dates use /bin/date (BSD) explicitly to avoid any PATH ambiguity. jq is
# resolved from the Home Manager profile, which the launchd agent PATH does
# not include.

ACAL="${ACAL:-$(command -v acal 2>/dev/null || echo /opt/homebrew/bin/acal)}"
JQ="${JQ:-$(command -v jq 2>/dev/null || echo "/etc/profiles/per-user/$(id -un)/bin/jq")}"
CALENDARS="9076C7CA-83B9-4E7A-8A92-44BC18D10392 E7BE7653-913E-48C1-848E-9C2FF5F4DCA7 A5F7884B-781A-4868-9958-BE7F3C347698"
CACHE="${TMPDIR:-/tmp}/sketchybar-next-event.cache"

now=$(/bin/date +%s)

read_cached_event() {
  [ -f "$CACHE" ] || return 1
  read -r e_start e_end e_title < "$CACHE" || return 1
  # Re-query once the event has ended or the sentinel expired.
  [ "$now" -lt "$e_end" ] || return 1
  return 0
}

fetch_event() {
  day0=$(/bin/date -v0H -v0M -v0S +%s)
  for offset in 0 1 2 3 4 5 6; do
    from=$(/bin/date -u -r $((day0 + offset * 86400)) '+%Y-%m-%dT%H:%M:%SZ')
    to=$(/bin/date -u -r $((day0 + (offset + 1) * 86400 - 1)) '+%Y-%m-%dT%H:%M:%SZ')

    set --
    for calendar in $CALENDARS; do
      set -- "$@" --calendar "$calendar"
    done

    chunk=$("$ACAL" events list --from "$from" --to "$to" "$@" --utc --format json 2>/dev/null) || continue

    pick=$(printf '%s' "$chunk" | "$JQ" -r --argjson now "$now" '
      [ .data[]
        | select(.allDay | not)
        | {start: (.start | fromdateiso8601), end: (.end | fromdateiso8601), title}
        | select(.end > $now) ]
      | unique_by([.start, .title])
      | sort_by(.start)
      | .[0]
      | if . == null then empty
        else "\(.start) \(.end) \(.title)"
        end
      | gsub("[\\n\\r\\\\]"; " ")')

    if [ -n "$pick" ]; then
      printf '%s\n' "$pick" > "$CACHE"
      return 0
    fi
  done

  # Nothing upcoming (or every query failed): park an expiring sentinel so we
  # do not hammer EventKit from every clock tick.
  printf '0 %d (none)\n' "$((now + 120))" > "$CACHE"
  return 1
}

format_interval() {
  interval=$1

  if [ "$interval" -gt 43200 ]; then
    interval_label="$(( (interval + 43200) / 86400 ))d"
  elif [ "$interval" -ge 3600 ]; then
    interval_label="$(( (interval + 1800) / 3600 ))h"
  else
    rounded_minutes=$(( (interval + 30) / 60 ))
    [ "$rounded_minutes" -lt 1 ] && rounded_minutes=1
    [ "$rounded_minutes" -eq 1 ] && unit=minute || unit=minutes
    interval_label="$rounded_minutes $unit"
  fi
}

event_label=""
read_cached_event || { fetch_event || true; read_cached_event || true; }

if [ -n "${e_start:-}" ] && [ "$e_start" != "0" ]; then
  if [ "$now" -lt "$e_start" ]; then
    format_interval "$((e_start - now))"
    event_label=" · $e_title - in $interval_label"
  else
    format_interval "$((e_end - now))"
    event_label=" · $e_title - $interval_label left"
  fi
fi

clock="$(/bin/date +%a | cut -c1-2) $(/bin/date +%-m/%-d) $(/bin/date '+%-I:%M %p')"
sketchybar --set "$NAME" label="$clock$event_label"
