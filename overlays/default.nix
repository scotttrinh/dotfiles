{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
  packages = self + /packages;
in
self: super: {
  claude-code = self.callPackage "${packages}/claude-code" { };
}