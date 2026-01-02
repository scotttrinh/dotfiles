{ flake, ... }:

{
  imports = [
    flake.inputs.sops-nix.homeManagerModules.sops
  ];

  sops.defaultSopsFile = ../../secrets.yaml;
  sops.age.keyFile = "/Users/scotttrinh/.config/sops/age/keys.txt";
}
