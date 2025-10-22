
{ inputs, ... }: [
  inputs.rust-overlay.overlays.default
  #(final: prev: import ./uv.nix final prev)
]
