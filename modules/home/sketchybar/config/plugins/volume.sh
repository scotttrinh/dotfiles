#!/bin/sh

# Volume icon + current output device name. The 10-second poll catches device
# switches and mute toggles; the volume_change subscription makes volume keys
# feel instant.

state="$(osascript \
  -e 'set v to output volume of (get volume settings)' \
  -e 'set m to output muted of (get volume settings)' \
  -e 'return (v as text) & "|" & (m as text)' 2>/dev/null)"
volume="${state%%|*}"
muted="${state#*|}"

case "$volume" in ''|*[!0-9]*) volume=0 ;; esac

if [ "$muted" = "true" ] || [ "$volume" -eq 0 ]; then
  icon="󰖁"
elif [ "$volume" -lt 50 ]; then
  icon="󰕿"
else
  icon="󰕾"
fi

device="$(SwitchAudioSource -c -t output 2>/dev/null)"
device="${device#MacBook Pro }"

sketchybar --set "$NAME" icon="$icon" label="${device:-unknown}"
