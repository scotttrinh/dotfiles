#!/bin/sh

volume="${INFO:-}"
if [ -z "$volume" ]; then
  volume="$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)"
fi

case "$volume" in
  ''|*[!0-9]*) volume=0 ;;
esac

if [ "$volume" -eq 0 ]; then
  icon="󰖁"
elif [ "$volume" -lt 35 ]; then
  icon="󰕿"
elif [ "$volume" -lt 70 ]; then
  icon="󰖀"
else
  icon="󰕾"
fi

sketchybar --set "$NAME" icon="$icon" label="${volume}%"
