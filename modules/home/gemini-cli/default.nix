
{ flake, ... }:
{
  home.file.".gemini/settings.json".source = ./settings.json;
}
