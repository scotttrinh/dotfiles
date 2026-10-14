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
        hash = "sha256-Of/Rb/YPGdG8rdeqLiGOt04f0Rtt/zIrMGnNlujXlOE=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-f+o0KigwnNmswhPGWuT8YzAQOMv8BBZjC4CXTiaT/LE=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-vdLuxrU4M34KDdy6/A7wzam8c87d5jHyrDzjTdqMMW0=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-zYxpuCC0hqFMMicarQOdExFOb9Hh03Ci27KRLxH811c=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.13";
  rev = "ffa755693c703a6a9cd5cad069bc1796cd18ad6e";

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
