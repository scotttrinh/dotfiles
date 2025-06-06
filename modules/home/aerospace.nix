{ flake, ... }:
{
  home.file.".config/aerospace/aerospace.toml".source = "${flake.config.root}/aerospace.toml";
}