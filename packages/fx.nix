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
        hash = "sha256-B91PRz/GKKaCo1b/0vp1IFk7z8YRf4l7l44yEqy7vB4=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-zB+DQ6VFAppJNOAZS4nX+pWmHm81s7rXPAH5vpzKBTA=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-LyoZxG5vWyYoYopWbB8HyOji+DUIfrOeKUaA2cSOabE=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-F4CUZ1GUYFspzMW3UMfiFd5VFysR5lSQaqB2mdEUidM=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.6";
  rev = "c011b118f41ca6950e1f5e3deb38950ab0771a74";

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
