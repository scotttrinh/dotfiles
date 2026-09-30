#!/bin/sh

# Volume icon + level. The 10-second poll catches device switches and mute
# toggles; the volume_change subscription makes volume keys feel instant.
# Displays a headphone icon for headphones/AirPods, and speaker icons otherwise.

SWITCH_AUDIO="${SWITCH_AUDIO:-$(command -v SwitchAudioSource 2>/dev/null || echo /opt/homebrew/bin/SwitchAudioSource)}"

state="$(osascript \
  -e 'set v to output volume of (get volume settings)' \
  -e 'set m to output muted of (get volume settings)' \
  -e 'return (v as text) & "|" & (m as text)' 2>/dev/null)"
volume="${state%%|*}"
muted="${state#*|}"

case "$volume" in ''|*[!0-9]*) volume=0 ;; esac

device="$("$SWITCH_AUDIO" -c -t output 2>/dev/null)"
device_lower="$(printf '%s' "$device" | tr '[:upper:]' '[:lower:]')"

case "$device_lower" in
  *airpod*|*headphone*|*headset*|*earpod*|*earbud*|*earphone*|*beats*|app[0-9]*|*wh-*|*wf-*|*quietcomfort*)
    is_headphone=1
    ;;
  *)
    is_headphone=0
    ;;
esac

if [ "$is_headphone" -eq 1 ]; then
  if [ "$muted" = "true" ] || [ "$volume" -eq 0 ]; then
    icon="󰟎"
  else
    icon="󰋋"
  fi
else
  if [ "$muted" = "true" ] || [ "$volume" -eq 0 ]; then
    icon="󰖁"
  elif [ "$volume" -lt 50 ]; then
    icon="󰕿"
  else
    icon="󰕾"
  fi
fi

sketchybar --set "$NAME" icon="$icon" label="${volume}%"
