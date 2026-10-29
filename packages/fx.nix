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
        hash = "sha256-1hCbDKVfmz2YSezn4f19uyHJHNPhMWXVeRr/z05rdOM=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-IBZ1p9IbrUkLncKmf9AazHXEuicALpXExcrBm5pJ+rw=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-EsdPGL9HSYhOCgrfpjogqFU3s+G2laQtRi8VD5BHP+M=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-yQI4MrAy4BTggDc3YCK2LHMUvQt9Ym+sf46LYbbsSU4=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.15";
  rev = "1c65871266514071ae3598cbb729c56493422ec6";

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
