{ config, ... }:
{
  # https://nixos.asia/en/git
  programs = {
    git = {
      enable = true;
      settings = {
        user = {
          name = config.me.fullname;
          email = config.me.email;
        };
        init.defaultBranch = "main";
        credential.helper = "manager";
      };
      ignores = [
        ".dir-locals.el"
        ".envrc"
        ".DS_Store"
        ".log"
        ".direnv"
        "*~"
        "*.swp"
        ".locals-only"
        ".agent-shell"
      ];
    };
  };

}
