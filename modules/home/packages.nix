{ pkgs, flake, ... }:
{
  # Nix packages to install to $HOME
  #
  # Search for packages here: https://search.nixos.org/packages
  home.packages = with pkgs; [
    (pkgs.buildGoModule {
      pname = "uncloud";
      version = "0.8.0";

      src = pkgs.fetchFromGitHub {
        owner = "psviderski";
        repo = "uncloud";
        rev = "v0.8.0";
        sha256 = "sha256-yc5CJPS3dX8KRXlXFobNOcWsUpfugDPIID5D81vlErc=";
      };

      vendorHash = "sha256-yh+omv8XnwiQv3JGTBV+1v3NvOTRQSJJ/AaeXOCBMH4=";

      doCheck = false;

      meta = {
        description = "A lightweight tool for deploying and managing containerised applications across a network of Docker hosts. Bridging the gap between Docker and Kubernetes.";
        homepage = "https://uncloud.run";
        license = pkgs.lib.licenses.asl20;
      };
    })
    (pkgs.buildGoModule {
      pname = "vimeo-dl";
      version = "0.2.0";

      src = pkgs.fetchFromGitHub {
        owner = "akiomik";
        repo = "vimeo-dl";
        rev = "v0.2.0";
        sha256 = "sha256-Ys1gFRi/9LftbAoW/wbkmh5wf+KxqgKSrKHExHtKIkg=";
      };

      vendorHash = "sha256-eKeUhS2puz6ALb+cQKl7+DGvm9Cl+miZAHX0imf9wdg=";

      meta = {
        description = "A simple command line tool for downloading videos from Vimeo";
        homepage = "https://github.com/akiomik/vimeo-dl";
        license = pkgs.lib.licenses.asl20;
      };
    })
    (pkgs.writeShellApplication {
      name = "edgedb-destroy-local-instances";
      runtimeInputs = [ pkgs.jq ];
      text = ''
        instances=$(edgedb instance list --json)
        local_instances=$(echo "$instances" | jq -r '.[] | select(has("service-status")) | .name')

        if [ -z "$local_instances" ]; then
          echo "No local instances to destroy."
          exit 0
        fi

        echo "The following local instances will be destroyed:"
        echo "$local_instances"
        echo

        read -r -p "Are you sure you want to destroy these instances? (y/N): " confirm
        if [[ "$confirm" != "y" ]]; then
          echo "Aborted."
          exit 0
        fi

        for instance in $local_instances; do
          echo "Destroying local instance: $instance"
          edgedb instance destroy --force -I "$instance"
        done

        echo "All selected local instances destroyed."
      '';
    })
    age
    sops
    ffmpeg
    unrar
    cloudflared
    yt-dlp
    ocamlPackages.ocaml-lsp
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
    flake.inputs.eza.packages.aarch64-darwin.default
    nix-tree
    devenv
    graphviz
    nixfmt
    codex

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
