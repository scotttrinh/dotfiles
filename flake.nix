{
  description = "Scott's Nix Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    mk-darwin-system = {
      url = "github:vic/mk-darwin-system/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-emacs.url = "github:cmacrae/emacs";
  };

  outputs = { self, mk-darwin-system, nixpkgs, mac-emacs, ... }@inputs:
    let
      flake-utils = mk-darwin-system.inputs.flake-utils;
      hostName = "cala-2021-mbp-13";
      systems = [ "aarch64-darwin" ];
    in flake-utils.lib.eachSystem systems (system:
      mk-darwin-system.mkDarwinSystem {
        inherit hostName system;

        silliconOverlay = silliconPkgs: intelPkgs: {
          inherit (silliconPkgs) emacs;
        };

        nixosModules = [
          ({ pkgs, ... }: {
            system.stateVersion = 4;
            system.keyboard.enableKeyMapping = true;
            system.keyboard.remapCapsLockToEscape = true;
            system.defaults.dock.autohide = true;
            system.defaults.dock.mru-spaces = false;
            system.defaults.dock.orientation = "left";
            # For doom-emacs
            system.activationScripts.postUserActivation.text = ''
              # Clone to $XDG_CONFIG_HOME because Emacs expects this location.
              if [[ ! -d "/Users/scotttrinh/.config/emacs" ]]; then
                git clone https://github.com/hlissner/doom-emacs "/Users/scotttrinh/.config/emacs"
              fi
            '';

            programs.zsh.enable = true;

            services.nix-daemon.enable = true;

            nixpkgs.overlays = [
              mac-emacs.overlay
            ];

            nix.package = pkgs.nixFlakes;
            nix.extraOptions = ''
              system = aarch64-darwin
              extra-platforms = aarch64-darwin x86_64-darwin
              experimental-features = nix-command flakes
              build-users-group = nixbld
            '';
            nix.binaryCaches = [ "https://cachix.org/api/v1/cache/emacs" ];
            nix.binaryCachePublicKeys = [
              "emacs.cachix.org-1:b1SMJNLY/mZF6GxQE+eDBeps7WnkT0Po55TAyzwOxTY="
            ];

            environment.systemPackages = with pkgs; [ nixFlakes home-manager ];

            users.users.scotttrinh.home = "/Users/scotttrinh";

            fonts.enableFontDir = true;
            fonts.fonts = with pkgs; [
              emacs-all-the-icons-fonts
              fira-code
              font-awesome
              roboto
              roboto-mono
            ];

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.scotttrinh = {
              home.packages = with pkgs; [
                (ripgrep.override { withPCRE2 = true; })
                gnutls
                emacs
                fd
                sqlite
                nodePackages.javascript-typescript-langserver
              ];
            };
          })
        ];

        flakeOutputs = { pkgs, ... }@outputs:
          outputs // (with pkgs; { packages = { inherit hello; }; });

      });
}
