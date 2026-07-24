{ lib
, stdenvNoCC
, fetchurl
,
}:

let
  platform =
    {
      aarch64-darwin = {
        name = "macos-aarch64";
        hash = "sha256-nLpvqK0tfWlJiKFbQNHcF9Rfa9e8MFibYuEuwBcvYZo=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-GX0xmhMGXtMKObIX+ulS6sVAELjoXVXpJWZvG1zfzYU=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-hj1HnRfUJAaoR2UB/bkKdFnMo2Bqdzb5f+4+Lucep7o=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-vZrSlxMSM26TcvbRfKGG6Z4yCafXle0cxgX+aF/mwXE=";
      };
    }.${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.3.55";

  src = fetchurl {
    url = "https://ugiwefobuo4tac0m.public.blob.vercel-storage.com/cli/v${finalAttrs.version}/fx-${platform.name}.tar.gz";
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
