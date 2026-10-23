{ config, ... }:
let
  # Gemini CLI layers system defaults below ~/.gemini/settings.json, so the
  # managed file goes there and settings.json stays writable by the CLI.
  systemDefaults = "agent-defaults/gemini/system-defaults.json";
in
{
  xdg.configFile.${systemDefaults}.source = ./settings.json;
  home.sessionVariables.GEMINI_CLI_SYSTEM_DEFAULTS_PATH = "${config.xdg.configHome}/${systemDefaults}";
}
