{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  platform =
    {
      aarch64-darwin = {
        name = "macos-aarch64";
        hash = "sha256-QnGKPhgnsT21TPu/2V0GNDG+RbZgXELnqLqB8PoLlzI=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-RIWJjLcelcciv1rhgPD+PxjTSGB4jfagyXVlhFUQ9CE=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-LmnSV6O6gNt+BkP+FjanhnWuVThlBpMD2nn7lCMMT0E=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-P6hZ6NbirWLI80H3mukrrIIJulUiqRS6EptxDi2irmE=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.11";
  rev = "9ce38a9454353b0972d0824f7fc8784276435e26";

  src = fetchurl {
    url = "https://releases.fx.sh/dev/${finalAttrs.rev}/fx-${platform.name}.tar.gz";
    inherit (platform) hash;
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 fx "$out/bin/fx"

    runHook postInstall
  '';

  meta = {
    description = "Vercel private fx CLI";
    homepage = "https://cdn.fx.labs.vercel.dev/install.sh";
    license = lib.licenses.unfree;
    mainProgram = "fx";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})
