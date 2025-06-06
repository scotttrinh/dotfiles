{ pkgs, ... }:
{
  programs.emacs = {
    enable = true;
    extraPackages = epkgs: with epkgs; [
      vterm
      treesit-grammars.with-all-grammars
    ];
  };
}
