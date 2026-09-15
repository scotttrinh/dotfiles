{ config, lib, pkgs, ... }:
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    selectedPackages.sketchybar = pkgs.sketchybar;

    programs.sketchybar = {
      enable = true;
      package = config.selectedPackages.sketchybar;
      configType = "bash";
      config = {
        source = ./config;
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
