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
        hash = "sha256-bzmM41IeCoqBBeL+gugxWUhZppvu54BjSKMIGaY2e5E=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-/tthcqxmLcHMl4ALPntGfAAihApCqLn5JUElrS3vQOw=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-XZHc/zHAJoMq23R3T6fNCn3JkWxwctTwypLIS2uznp8=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-EKez50e6O1hTF8F6NebOS0I0/nIXVrfY5h5uscMtGeU=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.7";
  rev = "766e70f0106393b551e2363526cf6a41e60587c3";

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
