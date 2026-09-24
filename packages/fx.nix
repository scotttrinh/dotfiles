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
        hash = "sha256-tQQCimqoocw4eKRRaOeH5Ze8gVLWTJTTg/FQ7FduEKc=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-UZTg53T8PdbEaS13YzruZj3Qf8CNHXmgvZadgNOgcp0=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-mAVDsB/5SbO96qv/UCN1FAYOmbQzgQ9qIsozgww4Mbs=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-EHKYQqE8aXC3s2YRvLmFfFthcRdK7BPDqkV1DdxNTC4=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.11";
  rev = "c95fcc66ada9bea4629f73199391c8a26438d760";

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
