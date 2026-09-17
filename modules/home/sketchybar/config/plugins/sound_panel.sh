#!/bin/sh

# Open the native Control Center sound dropdown. Requires /usr/bin/osascript
# in System Settings -> Privacy & Security -> Accessibility (one-time). Falls
# back to the Sound settings pane when assistive access is unavailable.

osascript -e 'tell application "System Events" to tell process "ControlCenter" to click (first menu bar item of menu bar 1 whose description is "Sound")' \
  || open 'x-apple.systempreferences:com.apple.Sound-Settings.extension'
