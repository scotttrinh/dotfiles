{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
self: super: {
}
