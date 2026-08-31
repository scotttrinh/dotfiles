let
  flake = builtins.getFlake (toString ../.);
  host = builtins.getEnv "PACKAGE_HOST";
  packages = flake.darwinConfigurations.${host}.config.home-manager.users.scotttrinh.selectedPackages;
in
builtins.mapAttrs (_: package: package.version or null) packages
