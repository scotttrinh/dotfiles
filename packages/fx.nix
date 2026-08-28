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
        hash = "sha256-EXzOytsUUl0sHK8eo0yacEAs4YoKqOJse33JAHZweNI=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-iAQPMos1i948eLBLLjgpK5Iuk7q49fe99mFwXK+QbgY=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-iWGc2IQnh8Umy4Fvh2o8pxetiBS6mO+GglVqv2whqU0=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-6xRNn+dTL2kRRczBv9DsUysNu0vVFiQUZRcnzPkoIF0=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.6";
  rev = "1b87677de6ff787ac0ce19a88dc1ca8a860a25d3";

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
