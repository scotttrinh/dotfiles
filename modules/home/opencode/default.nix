{ flake, ... }:
{
  home.file.".config/opencode/opencode.json".source = ./opencode.json;
}
