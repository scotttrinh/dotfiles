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
        hash = "sha256-lfMEkF1V8sFgEHGm+ZTuIz3V08MZimkvSLwEFxWOCm4=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-Cw89QAZbfthPXndgyS0W2fsBwraKGBqCrOtrORFtxWs=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-xu9kiBG9kTtmvLuCFBKtOZTzFjOyuDw7+M/uJsLkcEE=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-X2FbtUCN5oeJp31KCKPbv8RCOPTZ8UX5T+jVm4pjMOI=";
      };
    }.${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.3.58";

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
