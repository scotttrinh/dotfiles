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
        hash = "sha256-l53VQzsETJIPXES4guwpbr910J6ov9Ytna6JAg/rOXA=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-8EhYF5VGOeGCY3qdd5inrfEcD/8KXdZpk21+2AUMhxI=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-gYRG+jwVC39reXoIbRCIaUU4f9dN57Yb6iaXd72hvn0=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-RJCR7b9B1Orf45FuJPytfyUC2B3Tawld0oGvk4I4kVY=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.10";
  rev = "e45d780933bfb42ae376aee54a49bd3ebe81f04d";

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
