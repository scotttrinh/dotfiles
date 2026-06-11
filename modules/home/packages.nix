{ flake, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  selfPackages = flake.inputs.self.packages.${system};
  jj = flake.inputs.jj.packages.${system}.default;
  llm-agents = flake.inputs.llm-agents.packages.${system};
  llm-agents-mimo-code = flake.inputs.llm-agents-mimo-code.packages.${system};
in
{
  # Nix packages to install to $HOME
  #
  # Search for packages here: https://search.nixos.org/packages
  home.packages = with pkgs; [
    selfPackages.ty
    selfPackages.uv
    age
    sops
    ffmpeg
    unar
    nodejs_24
    corepack_24
    python312
    git-credential-manager
    bun
    vsce
    cmake
    fontconfig
    geist-font
    nerd-fonts.symbols-only
    nerd-fonts.geist-mono
    symbola
    inetutils
    typescript
    typescript-language-server
    vscode-langservers-extracted
    prettier
    flake.inputs.eza.packages.${system}.default
    nix-tree
    devenv
    graphviz
    nixfmt
    parinfer-rust-emacs
    hyperfine
    jj
    llm-agents.claude-code
    llm-agents.codex-acp
    llm-agents.opencode
    llm-agents.antigravity-cli
    llm-agents.amp
    llm-agents-mimo-code.mimo-code

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

  # Doom's doctor uses fc-list even on macOS. Generate a Fontconfig catalog
  # that includes fonts installed through the Home Manager profile.
  fonts.fontconfig.enable = true;

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
