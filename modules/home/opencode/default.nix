{ ... }:
{
  imports = [ ../agent-defaults ];

  agentDefaults.files."opencode/opencode.json" = {
    target = ".config/opencode/opencode.json";
    content = builtins.readFile ./opencode.json;
  };
}
