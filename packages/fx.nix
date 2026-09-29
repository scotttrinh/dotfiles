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
        hash = "sha256-9bkg1lR/9tb0hmU43q+5WEkq/H+EGn8iL+LdDRTmmcg=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-1vFrz8QAtvJcaCzp++Z7WWvTpS4otunDSE9thjPCNew=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-Lz5rjKkcN5jlP8C8/gFy8TTVNmdieOxoalCaGGkWMVA=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-FmmzMfgXX0Xdt1gho9XgaGbadvThm/wMTNwDdld9WFQ=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.11";
  rev = "77172900f67c3b598f436769bfd5131da35856e6";

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
