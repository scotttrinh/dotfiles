#!/bin/sh

. "$CONFIG_DIR/colors.sh"

workspace="$1"
focused_workspace="${FOCUSED_WORKSPACE:-}"

if [ -z "$focused_workspace" ] && command -v aerospace >/dev/null 2>&1; then
  focused_workspace="$(aerospace list-workspaces --focused 2>/dev/null)"
fi

if [ "$workspace" = "$focused_workspace" ]; then
  sketchybar --set "$NAME" \
    background.color="$ACCENT_COLOR" \
    label.color=0xff17191f
else
  sketchybar --set "$NAME" \
    background.color="$ITEM_BG_COLOR" \
    label.color="$TEXT_COLOR"
fi
