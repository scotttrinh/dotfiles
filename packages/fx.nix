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
        hash = "sha256-bnmfU9mUSbkKhlY35wPYrBQxENMlDr/DTl2yAaO65Yc=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-It0BDGp0USDZC66RKbjT/FIfkaFY+I6ICXydRpxTXOE=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-FfRTAsvkxxOQL4XCmeHaaCM8WH5GPlGgccIGEcqB1CY=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-IYcOGTOqznHJO/dPgmxCVlEmhAeJsfMQIcOrcZxto9I=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.16";
  rev = "7f24144a662b78092aec18be2830742a65f4c698";

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
