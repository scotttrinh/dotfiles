{ config, lib, ... }:

let
  cfg = config.codex;
in
{
  options.codex = {
    enable = lib.mkEnableOption "Codex CLI";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Codex package to install. Set to null to manage installation elsewhere.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;
  };
}
