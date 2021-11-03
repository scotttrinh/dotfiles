{
  description = "Scott's Nix Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    mk-darwin-system = {
      url = "github:vic/mk-darwin-system/main";
    };

    mac-emacs = {
      url = "github:cmacrae/emacs";
    };
  };

  outputs = { self, mk-darwin-system, nixpkgs, mac-emacs, ... }@inputs:
    let
      flake-utils = mk-darwin-system.inputs.flake-utils;
      hostName = "cala-2021-mbp-13";
      systems = [ "aarch64-darwin" ];
    in flake-utils.lib.eachSystem systems (system:
      mk-darwin-system.mkDarwinSystem {
        inherit hostName system;

        nixosModules = [
          ./modules/emacs.nix
          ./modules/homebrew.nix
          ./modules/git.nix
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
                tilesize = 16;
              };
            };

            system.screenCapture.location = "~/ScreenCaptures";

            system.trackpad = {
              Clicking = true;
              TrackpadRightClick = true;
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
              ];
              config.allowUnfree = true;
            };

            nix = {
              package = pkgs.nixUnstable;
              extraOptions = ''
                system = aarch64-darwin
                extra-platforms = aarch64-darwin x86_64-darwin
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
              ];
            };
          })
        ];

        flakeOutputs = { pkgs, ... }@outputs:
          outputs // (with pkgs; { packages = { inherit hello; }; });

      });
}
