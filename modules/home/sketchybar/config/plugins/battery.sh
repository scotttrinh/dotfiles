#!/bin/sh

battery_status="$(pmset -g batt 2>/dev/null)"
percentage="$(printf '%s\n' "$battery_status" | sed -n 's/.*[[:space:]]\([0-9][0-9]*\)%.*/\1/p' | head -n 1)"

if [ -z "$percentage" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

case "$battery_status" in
  *AC\ Power*|*charging*) icon="󰂄" ;;
  *)
    if [ "$percentage" -le 20 ]; then
      icon="󰁺"
    elif [ "$percentage" -le 50 ]; then
      icon="󰁾"
    elif [ "$percentage" -le 80 ]; then
      icon="󰂁"
    else
      icon="󰁹"
    fi
    ;;
esac

sketchybar --set "$NAME" drawing=on icon="$icon" label="${percentage}%"
