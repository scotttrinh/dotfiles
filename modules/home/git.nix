{ config, ... }:
{
  # https://nixos.asia/en/git
  programs = {
    git = {
      enable = true;
      userName = config.me.fullname;
      userEmail = config.me.email;
      ignores = [
        ".dir-locals.el"
        ".envrc"
        ".DS_Store"
        ".log"
        ".direnv"
        "*~"
        "*.swp"
      ];
      extraConfig = {
        init.defaultBranch = "main";
      };
    };
  };

}