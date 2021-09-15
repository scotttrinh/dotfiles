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
    import ./scott (mk-darwin-system.inputs // {
      scott = self;
      inherit nixpkgs;
      inherit (mk-darwin-system) mkDarwinSystem;
    });
}
