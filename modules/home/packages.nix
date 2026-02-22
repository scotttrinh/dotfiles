{ flake, pkgs, ... }:
let
  packages = flake.inputs.self + /packages;
  llm-agents = flake.inputs.llm-agents.packages.${pkgs.system};
in {
  # Nix packages to install to $HOME
  #
  # Search for packages here: https://search.nixos.org/packages
  home.packages = with pkgs; [
    (import (flake.inputs.self + /packages/pi.nix) { inherit pkgs; })
    (import (flake.inputs.self + /packages/ty.nix) { inherit pkgs; })
    age
    sops
    ffmpeg
    unar
    nodejs_24
    corepack_24
    python312
    uv
    git-credential-manager
    bun
    vsce
    cmake
    fontconfig
    nerd-fonts.symbols-only
    inetutils
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted
    nodePackages.prettier
    flake.inputs.eza.packages.${pkgs.system}.default
    nix-tree
    devenv
    graphviz
    nixfmt
    parinfer-rust-emacs
    hyperfine
    llm-agents.claude-code
    llm-agents.claude-code-acp
    llm-agents.codex
    llm-agents.opencode
    llm-agents.gemini-cli
    llm-agents.amp
    llm-agents.cursor-agent

    # From template
    omnix
    ripgrep # Better `grep`
    fd
    sd
    tree
    gnumake
    cachix
    nil # Nix language server
    nix-info
    nixpkgs-fmt
    less
  ];

  # Programs natively supported by home-manager.
  # They can be configured in `programs.*` instead of using home.packages.
  programs = {
    # Better `cat`
    bat.enable = true;
    # Type `<ctrl> + r` to fuzzy search your shell history
    fzf.enable = true;
    jq.enable = true;
    # Install btop https://github.com/aristocratos/btop
    btop.enable = true;
    # Tmate terminal sharing.
    tmate = {
      enable = true;
      #host = ""; #In case you wish to use a server other than tmate.io 
    };
  };
}
