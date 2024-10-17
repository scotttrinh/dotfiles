{ self, ... }:
{
  flake = {
    homeModules = {
      common = {
        home.stateVersion = "22.11";
      };
      common-darwin = {
        imports = [
          self.homeModules.common
        ];
      };
    };
  };
}