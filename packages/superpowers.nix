{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "superpowers";
  version = "6.0.3";

  src = fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    tag = "v${finalAttrs.version}";
    hash = "sha256-+lT2a/qq0SF4k0PgnEDKiuidVlZX2p0vEso4d/5T1os=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R . "$out/"

    runHook postInstall
  '';

  meta = {
    description = "Superpowers skills and runtime bootstrap for coding agents";
    homepage = "https://github.com/obra/superpowers";
    license = lib.licenses.mit;
  };
})
