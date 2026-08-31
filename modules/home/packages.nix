{ flake
, pkgs
, ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  selfPackages = flake.inputs.self.packages.${system};
  llmAgents = flake.inputs.llm-agents.packages.${system};
  selectedPackages = with pkgs; {
    ty = selfPackages.ty;
    uv = selfPackages.uv;
    inherit
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
      symbola
      inetutils
      typescript
      typescript-language-server
      vscode-langservers-extracted
      prettier
      nix-tree
      graphviz
      nixfmt
      parinfer-rust-emacs
      hyperfine
      gh
      git-lfs
      omnix
      ripgrep
      fd
      sd
      tree
      gnumake
      cachix
      nil
      nix-info
      nixpkgs-fmt
      less
      ;
    geist-font = geist-font;
    nerd-fonts-symbols-only = nerd-fonts.symbols-only;
    nerd-fonts-geist-mono = nerd-fonts.geist-mono;
    eza = flake.inputs.eza.packages.${system}.default;
    devenv = flake.inputs.devenv.packages.${system}.default;
    jj = flake.inputs.jj.packages.${system}.default;
    herdr = flake.inputs.herdr.packages.${system}.default;
    claude-code = llmAgents.claude-code;
    codex-acp = llmAgents.codex-acp;
    opencode = llmAgents.opencode;
    antigravity-cli = llmAgents.antigravity-cli;
    amp = llmAgents.amp;
    mimo-code = llmAgents.mimo-code;
  };
in
{
  selectedPackages = selectedPackages // {
    inherit (pkgs) bat fzf jq btop tmate;
  };

  home.packages = builtins.attrValues selectedPackages;

  # Doom's doctor uses fc-list even on macOS. Generate a Fontconfig catalog
  # that includes fonts installed through the Home Manager profile.
  fonts.fontconfig.enable = true;

  programs = {
    bat.enable = true;
    fzf.enable = true;
    jq.enable = true;
    btop.enable = true;
    tmate.enable = true;
  };
}
