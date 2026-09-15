#!/bin/sh

if [ -n "${INFO:-}" ]; then
  sketchybar --set "$NAME" label="$INFO"
fi
