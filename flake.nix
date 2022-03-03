{
  description = "Scott's Nix Environment";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };

    mk-darwin-system = {
      url = "github:vic/mk-darwin-system/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-emacs = {
      url = "github:cmacrae/emacs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, mk-darwin-system, nixpkgs, mac-emacs, rust-overlay, ... }@inputs:
    let
      darwinFlakeOutput = mk-darwin-system.mkDarwinSystem.m1 {
        modules = [
          ./modules/emacs.nix
          ./modules/homebrew.nix
          ./modules/git.nix
          ./modules/terminal.nix
          ({ pkgs, ... }: {
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
            };

            environment = {
              shellAliases = {
                "ll" = "${pkgs.coreutils}/bin/ls --color=auto -lha";
              };

              variables = {
                NPM_CONFIG_PREFIX = "~/.npm-global";
              };

              systemPath = [
                "~/.npm-global"
              ];
            };

            programs.zsh = {
              enable = true;
            };

            services.nix-daemon.enable = true;

            nixpkgs = {
              overlays = [
                mac-emacs.overlay
                rust-overlay.overlay
              ];
              config.allowUnfree = true;
            };

            nix = {
              extraOptions = ''
                system = aarch64-darwin
                extra-platforms = x86_64-darwin
                experimental-features = nix-command flakes
                build-users-group = nixbld
              '';
              binaryCaches = [ "https://cachix.org/api/v1/cache/emacs" ];
              binaryCachePublicKeys = [
                "emacs.cachix.org-1:b1SMJNLY/mZF6GxQE+eDBeps7WnkT0Po55TAyzwOxTY="
              ];
            };

            users.users.scotttrinh.home = "/Users/scotttrinh";

            fonts = {
              enableFontDir = true;
              fonts = with pkgs; [
                fira-code
                font-awesome
                roboto
                roboto-mono
              ];
            };
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.scotttrinh.home.packages = with pkgs; [
                postgresql_13
                direnv
                bat
                openssh
                gnupg
                element-desktop
                rust-bin.stable.latest.default
                rust-analyzer
              ];
            };
          })
        ];
      };
    in darwinFlakeOutput // {
      darwinConfigurations."scotts-mbp-16".lan = darwinFlakeOutput.darwinConfiguration.aarch64-darwin;
    };

}
