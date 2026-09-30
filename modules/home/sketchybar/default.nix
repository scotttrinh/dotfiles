{ config, lib, pkgs, ... }:
let
  goPlugins = pkgs.callPackage ./go/package.nix { };
  sketchybarConfig = pkgs.runCommand "sketchybar-config" { } ''
    cp -R ${./config} "$out"
    chmod u+w "$out/plugins"
    cat > "$out/plugins/go_probe.sh" <<'EOF'
    #!/bin/sh
    if [ -x "$HOME/.local/bin/sketchybar-plugins" ]; then
      exec "$HOME/.local/bin/sketchybar-plugins" probe
    fi
    exec ${goPlugins}/bin/sketchybar-plugins probe
    EOF
    chmod +x "$out/plugins/go_probe.sh"
  '';
in
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    selectedPackages.sketchybar = pkgs.sketchybar;
    selectedPackages.sketchybar-plugins = goPlugins;

    programs.sketchybar = {
      enable = true;
      package = config.selectedPackages.sketchybar;
      configType = "bash";
      config = {
        source = sketchybarConfig;
        recursive = true;
      };
    };

    # Home Manager only reloads launch agents when their plist changes. Always
    # restart SketchyBar after activation so config changes take effect and a
    # temporarily hidden bar becomes visible again.
    home.activation.restartSketchybar = lib.hm.dag.entryAfter [ "setupLaunchAgents" ] ''
      /bin/launchctl kickstart -k "gui/$(id -u)/org.nix-community.home.sketchybar" 2>/dev/null || true
    '';
  };
}
