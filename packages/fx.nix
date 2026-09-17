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
        hash = "sha256-3bL/Et570B6o/mdroth7nzjlEin9+OK7Be2889mlHAA=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-lLU04n61fLsmoxawcbK9kc+4s+9oh8M/aDjiBOuerLE=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-MomyBb1nPds0CKAtH5Jmz5nO87Ij0F03C0gWTNkQPSY=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-0XnY74tTv03EAsyV9YL/MMjwqrTqMAXHp05RYROKMBQ=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.10";
  rev = "a8200bff1621c43476b0fa14f0ed523d09101b70";

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
