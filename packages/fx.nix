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
        hash = "sha256-S4aBtDEMBiMGzOfxzLzqAHihXP6N6tOhIM1oIFhoGvo=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-16MShnh3GS8ZWQbtvtQIf3wLSmfakErN0sbv5YTDHK8=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-Yemxk4AiyJvt6w51bTD8rmYRivDwinBSirdVFxF+tR0=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-HH7rLlm/jhezmv4Q1TOuy/nELqmqoDCkqfXMnUc+BnY=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.11";
  rev = "10bf719b6b0c1d941b2606f1cd544be5508e338e";

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
