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
        hash = "sha256-CoN7hB8LI9IPDoQkmzjOADi2BqNZ6CM+Is/P8mbA6aI=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-Ur4zrXfWx0m1JGkArfu2Udb28FPoVcCxP19EpcBu3ac=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-t8mo2RW1ekTYDhzEBdm4HGUeucaqydCiZvCBJQY1Ek0=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-YM013btuPTZ4/C1VsIPcYDdz+B7ppZhLZ/DlaUxODn4=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.7";
  rev = "ef03b480874a49a9cc508c39b7b98214c34178ee";

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
