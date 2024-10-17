{
  inputs = {
    # Principle inputs (updated by `nix run .#update`)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:lnl7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-flake.url = "github:srid/nixos-flake";
    eza.url = "https://flakehub.com/f/eza-community/eza/0.18.21.tar.gz";
  };

  outputs = inputs@{ self, ... }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-darwin" ];
      imports = [
        inputs.nixos-flake.flakeModule
        ./users
        #./home
      ];

      flake =
        let
          myUserName = "scotttrinh";
        in
        {
          # Configurations for macOS machines
          darwinConfigurations.frankie = self.nixos-flake.lib.mkMacosSystem {
            nixpkgs.hostPlatform = "aarch64-darwin";
            nixpkgs.config.allowUnfree = true;
            imports = [
              # Your nix-darwin configuration goes here
              ({ pkgs, ... }: {
                security.pam.enableSudoTouchIdAuth = true;
                # Used for backwards compatibility, please read the changelog before changing.
                # $ darwin-rebuild changelog
                system.stateVersion = 4;

                system.keyboard = {
                  enableKeyMapping = true;
                  remapCapsLockToEscape = true;
                };

                system.defaults = {
                  dock = {
                    autohide = true;
                    mru-spaces = false;
                    static-only = true;
                    orientation = "left";
                    tilesize = 32;
                  };

                  screencapture.location = "~/ScreenCaptures";

                  trackpad = {
                    Clicking = true;
                    TrackpadRightClick = true;
                  };

                  NSGlobalDomain = {
                    NSAutomaticPeriodSubstitutionEnabled = false;
                    NSAutomaticSpellingCorrectionEnabled = false;
                  };
                };

                nix.useDaemon = true;
                nix.settings.experimental-features = "nix-command flakes";
              })
              # Setup home-manager in nix-darwin config
              self.darwinModules_.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.${myUserName} = {
                  imports = [ self.homeModules.default ];
                  home.stateVersion = "22.11";
                };

                users.users."${myUserName}".home = "/Users/${myUserName}";
              }
            ];
          };

          # home-manager configuration goes here.
          homeModules.default = { pkgs, ... }: {
            imports = [ ];
            home.file.".config/aerospace/aerospace.toml".source = ./aerospace.toml;
            home.packages = with pkgs; [
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
              /*
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

                  read -pr "Are you sure you want to destroy these instances? (y/N): " confirm
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
              */
              ffmpeg
              unrar
              cloudflared
              yt-dlp
              ocamlPackages.ocaml-lsp
              ripgrep
              nodejs_20
              corepack_20
              yarn
              vsce
              nodePackages.typescript
              nodePackages.typescript-language-server
              nodePackages.vscode-langservers-extracted
              nodePackages.prettier
              inputs.eza.packages.aarch64-darwin.default
            ];
            programs.git = {
              enable = true;
              userName = "Scott Trinh";
              userEmail = "scott@scotttrinh.com";
              ignores = [
                ".dir-locals.el"
                ".envrc"
                ".DS_Store"
                ".log"
                ".direnv"
              ];
              extraConfig = {
                init.defaultBranch = "main";
              };
            };
            programs.starship.enable = true;
            programs.zsh.enable = true;
            programs.direnv = {
              enable = true;
              enableZshIntegration = true;
              nix-direnv.enable = true;
            };
            programs.emacs = {
              enable = true;
              extraPackages = epkgs: with epkgs; [
                vterm
                treesit-grammars.with-all-grammars
              ];
            };
            programs.wezterm = {
                enable = true;
                enableZshIntegration = true;
                enableBashIntegration = true;
                extraConfig = builtins.readFile ./wezterm.lua;
            };
          };
        };
    };
}
