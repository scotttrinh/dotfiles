{ flake, pkgs, ... }:
{
  home.file.".config/aerospace/aerospace.toml".source = ./aerospace.toml;

  # Monitor -> root layout map. apply (no args) restores the layout last used
  # on the focused monitor, falling back to tiles on external displays and
  # accordion on the built-in panel. toggle-tiles / toggle-accordion are bound
  # to alt-slash / alt-comma: cycle the root layout, then record it.
  # Wired from aerospace.toml (after-startup-command,
  # on-focused-monitor-changed, exec-on-workspace-change).
  home.file.".config/aerospace/monitor-layout.sh".source = pkgs.writeShellScript "aerospace-monitor-layout" ''
    STATE="$HOME/.config/aerospace/monitor-layouts.tsv"

    record() {
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
      monitor=$(aerospace list-monitors --focused --format '%{monitor-name}') || return 0
      case "$monitor" in
        *Built-in*) layout=h_accordion ;;
        *) layout=tiles ;;
      esac
      recorded=$(awk -F '\t' -v m="$monitor" '$1 == m { print $2 }' "$STATE" 2>/dev/null)
      [ -n "$recorded" ] || recorded=$layout
      if [ -n "$AEROSPACE_FOCUSED_WORKSPACE" ]; then
        aerospace layout --workspace "$AEROSPACE_FOCUSED_WORKSPACE" --root "$recorded" >/dev/null 2>&1 || true
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
