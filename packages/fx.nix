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
        hash = "sha256-sTdbyxcBTwHK3dxHruDv1SRrU82Xm7E13nt+V+45Paw=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-aH0uVW+wSLDbd43049RkFT9rlsuU00vcu1U61BhDA6k=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-BWwIogqovgrYbKAFa5MsLFnIXxhfG5NEfGq0oCXphZM=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-WKqYsF8sSdGKKYVKC3U4oI/JATBTG6R4lhgTR/3hhLg=";
      };
    }.${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.3.61";

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
