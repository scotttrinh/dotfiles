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
        hash = "sha256-jmxOkmXEb5o6xnzPzfbHeo8qq+mMvc5q27D2LanuW9Q=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-KLYrw/q0Qq1IJXy6KdlAVHH+2L7Q3Oikq8aglXBZLD0=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-45H+42bnk0zVEmJvMfR+xuv3I82o1kKnJZeKMCDjdXU=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-r/12na89g/Ys4PYc22NiD5BbzyYEkZH3k9Y0pZN2Dtk=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.11";
  rev = "d881a226962d9fe8bc79f6c0437729bb21e25749";

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
