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
        hash = "sha256-yyms9k5Ue50TdK3SV8jc+k7nA1ZNMBQ7DvZOrXhWQYA=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-FQ/7sWRuOe38OyoJk0wbNGevwF1PbDUWp/YtWQdaK0M=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-bt+kFX9mfi3tDyGbeemcIxESLnosR7MAdE9YxBh9DNU=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-2UwgKTjFAoJ5ybDnmDC64xRFWPFYUPI0NbH5Lvar+GM=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.17";
  rev = "11a6daf7d5001592158b24e8c0d5612e8c2e5de1";

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
