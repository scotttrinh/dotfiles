{ flake, pkgs, ... }:
{
  home.file.".config/aerospace/aerospace.toml" = {
    source = ./aerospace.toml;
    onChange = ''
      PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
      if command -v aerospace >/dev/null 2>&1 && pgrep -x AeroSpace >/dev/null 2>&1; then
        echo "Reloading AeroSpace config..."
        aerospace reload-config || true
      fi
    '';
  };

  # Monitor -> root layout map. apply (no args) restores the layout last used
  # on the focused monitor, falling back to tiles on external displays and
  # accordion on the built-in panel. toggle-tiles / toggle-accordion are bound
  # to alt-slash / alt-comma: cycle the root layout, then record it.
  # Wired from aerospace.toml (after-startup-command,
  # on-focused-monitor-changed, exec-on-workspace-change).
  home.file.".config/aerospace/monitor-layout.sh".source = pkgs.writeShellScript "aerospace-monitor-layout" ''
    STATE="$HOME/.config/aerospace/monitor-layouts.tsv"

    record() {
      current_ws=$(aerospace list-workspaces --focused 2>/dev/null)
      case "$current_ws" in
        1|2) return 0 ;;
      esac
      monitor=$(aerospace list-monitors --focused --format '%{monitor-name}') || return 0
      layout=$(aerospace list-windows --focused --format '%{workspace-root-container-layout}') || return 0
      [ -n "$monitor" ] && [ -n "$layout" ] || return 0
      mkdir -p "$(dirname "$STATE")"
      touch "$STATE"
      awk -F '\t' -v m="$monitor" -v l="$layout" \
        '$1 == m { print m "\t" l; found = 1; next } { print } END { if (!found) print m "\t" l }' \
        "$STATE" > "$STATE.tmp.$$" && mv "$STATE.tmp.$$" "$STATE"
    }

    apply() {
      target_ws="$AEROSPACE_FOCUSED_WORKSPACE"
      [ -n "$target_ws" ] || target_ws=$(aerospace list-workspaces --focused 2>/dev/null)
      case "$target_ws" in
        1)
          aerospace layout --workspace 1 --root h_accordion >/dev/null 2>&1 || true
          return 0
          ;;
        2)
          aerospace layout --workspace 2 --root h_tiles >/dev/null 2>&1 || true
          return 0
          ;;
      esac

      monitor=$(aerospace list-monitors --focused --format '%{monitor-name}') || return 0
      case "$monitor" in
        *Built-in*) layout=h_accordion ;;
        *) layout=tiles ;;
      esac
      recorded=$(awk -F '\t' -v m="$monitor" '$1 == m { print $2 }' "$STATE" 2>/dev/null)
      [ -n "$recorded" ] || recorded=$layout
      if [ -n "$target_ws" ]; then
        aerospace layout --workspace "$target_ws" --root "$recorded" >/dev/null 2>&1 || true
      else
        aerospace layout --root "$recorded" >/dev/null 2>&1 || true
      fi
    }

    case "$1" in
      toggle-tiles)
        aerospace layout --root tiles horizontal vertical >/dev/null 2>&1 || true
        record
        ;;
      toggle-accordion)
        aerospace layout --root accordion horizontal vertical >/dev/null 2>&1 || true
        record
        ;;
      *)
        apply
        ;;
    esac
  '';
}
