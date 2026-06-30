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
        hash = "sha256-+H3vXmfU/P7TITuf0XcfGQFaKrdTIW1DII0CsTB+c+w=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-h2QEt8HbKASu2BPYDAZV23hn/U92vVTM/IceAueAM2Q=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-ZldlgH4yuTDpoZpAS4D/0y8HWeBkhtBYPOGHdGl4Bzw=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-D75Q8zR0PyV08oWNPoFhToP/Yw/PMPhRLMG3+zut9gQ=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.3.35";

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
