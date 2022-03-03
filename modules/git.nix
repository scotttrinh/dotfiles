{ pkgs, ... }: {
  home-manager.users.scotttrinh.programs.git = {
    package = pkgs.git;
    enable = true;
    userName = "Scott Trinh";
    userEmail = "scott@ca.la";
    ignores = [
      ".dir-locals.el"
      ".envrc"
      ".DS_Store"
      ".log"
    ];
    extraConfig = {
      init.defaultBranch = "main";
    };
  };
}
