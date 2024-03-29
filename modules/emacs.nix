{ pkgs, ... }: {
  system.activationScripts.postUserActivation.text = ''
    # Clone to $XDG_CONFIG_HOME because Emacs expects this location.
    if [[ ! -d "/Users/scotttrinh/.config/emacs" ]]; then
      git clone https://github.com/hlissner/doom-emacs "/Users/scotttrinh/.config/emacs"
    fi
    if [[ ! -d "/Users/scotttrinh/.config/doom" ]]; then
      git clone https://github.com/scotttrinh/doom-emacs-config.git "/Users/scotttrinh/.config/doom"
    fi
  '';

  fonts.fonts = with pkgs; [
    emacs-all-the-icons-fonts
  ];

  home-manager.users.scotttrinh.home.packages = with pkgs; [
    (ripgrep.override { withPCRE2 = true; })
    gnutls
    fd
    sqlite
    nodejs-16_x
    yarn
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.prettier
    vscode-extensions.chenglou92.rescript-vscode
    emacs
  ];
}
