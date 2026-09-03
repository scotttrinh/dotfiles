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
        hash = "sha256-dzSI/TjuxgmhvUqZdV8GoOI9W0a7nh9j0w1cATXJtko=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-M6ki3XJBLxKQXuOyvEZvtWw/DK2Zheu76Xo07yZTPt0=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-zjWNvnt+hwajw1w3m3A4xWB11MoBnEmIGKJ1QXK64W8=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-FBqxInkJD2YBNJziZpm2ej3YX53vKR4KaWLW2hVk84E=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.7";
  rev = "d6059c20aaa0f1a4ff0f00cebd418a930c146f1a";

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
