{ flake, config, ... }:

{
  imports = [
    flake.inputs.sops-nix.homeManagerModules.sops
  ];

  sops.defaultSopsFile = ../../secrets.yaml;
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  sops.secrets.emacs_authinfo = {
    key = "EMACS_AUTHINFO";
    path = "${config.home.homeDirectory}/.authinfo";
    mode = "0400";
  };
}
