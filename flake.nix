{
  description = "Scott's Nix Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master";

    mk-darwin-system = {
      url = "github:vic/mk-darwin-system/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, mk-darwin-system, nixpkgs, ... }@inputs:
    let
      flake-utils = mk-darwin-system.inputs.flake-utils;
      hostName = "cala-2021-mbp-13";
      systems = [ "aarch64-darwin" ];
    in flake-utils.lib.eachSystem systems (system:
      mk-darwin-system.mkDarwinSystem {
        inherit hostName system;

        nixosModules = [
          ({ pkgs, ... }: {
            system.stateVersion = 4;
            programs.zsh.enable = true;
            services.nix-daemon.enable = true;
            nix.package = pkgs.nixFlakes;
            nix.extraOptions = ''
              system = aarch64-darwin
              extra-platforms = aarch64-darwin x86_64-darwin
              experimental-features = nix-command flakes
              build-users-group = nixbld
            '';
            environment.systemPackages = with pkgs; [ nixFlakes home-manager ];
            users.users.scotttrinh.home = "/Users/scotttrinh";
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.scotttrinh = {
              home.packages = with pkgs; [ ripgrep ];
            };
          })
        ];

        flakeOutputs = { pkgs, ... }@outputs:
          outputs // (with pkgs; { packages = { inherit hello; }; });

      });
}
