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
        hash = "sha256-7AdRYFnSz0Dl6Vytr0Mli8kT9d9omZuP3empCsSnDE0=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-UFQ2/oUp5WY2HIPb4mWw9xZN8o+yDuPdyhJVI81f8Po=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-lYsb/eZKe8BuMQ5I8NH+8iyWnsSFHR8Tfo4Vayx+kgI=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-LSIaJ3ir2sU1tGrxy6YLk1+Ad5Q+Ihr6XTPTyO6Pryg=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.6";
  rev = "fcebd11aac21b9c440d1460d4a395e16ddbea23e";

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
