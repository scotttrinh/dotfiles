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
        hash = "sha256-Afxiu/yXUo93mCYHMo+WP/ODx/ZJc1uR1WMugGfpaYY=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-6toFL8pqsWxCHQM9VYndZkEJw5/pBTdGywWOQbA3rwE=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-f6qQ/8Bn8/cjQrv59oV5hbI16fmq3PIsUz3a8VWQTNQ=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-8j48IWvG2XOwLhdeve2iQlhBoKaR5v/8hbsQZR0/vSw=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.3.51";

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
