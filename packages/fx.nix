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
        hash = "sha256-RuJKtu3wg1r3MA54v7NMZRETVH2ymWFNZlZTIGVmWTY=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-ShdOQdeDaQbrWAVVUe2X5ZE0KdY75x11bWhBUuiGdH4=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-9xurnG4clBWrXRqGgwPHoif4XnMPojrFK1Ed4LYW4F0=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-DykJbUvqISQll3EDKfLu2LSl0ArfEurKOyxqNNX7mM4=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.7";
  rev = "ffd050d029d46316a31d6f50aead09d11febc1e2";

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
