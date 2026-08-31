{ config
, lib
, ...
}:
let
  manifest = builtins.mapAttrs
    (_: package: {
      version = package.version or null;
      path = "${package}";
    })
    config.selectedPackages;
in
{
  options.selectedPackages = lib.mkOption {
    type = lib.types.attrsOf lib.types.package;
    default = { };
    description = "Intentionally selected packages tracked across updates and activations.";
  };

  config.xdg.stateFile."selected-packages.json".text = builtins.toJSON manifest;
}
