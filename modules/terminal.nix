{ pkgs, ... }: {
  home-manager.users.scotttrinh.programs.alacritty = {
    package = pkgs.alacritty;
    enable = true;
    settings = {
      font = {
        size = 16;
      };
    };
  };
}
