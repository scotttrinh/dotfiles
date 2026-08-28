let
  flake = builtins.getFlake (toString ../.);
in
import ./llm-agents-manifest.nix {
  input = flake.inputs.llm-agents;
  system = builtins.currentSystem;
}
