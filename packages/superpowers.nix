{ lib
, stdenvNoCC
, fetchFromGitHub
,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "superpowers";
  version = "6.3.0";

  src = fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    tag = "v${finalAttrs.version}";
    hash = "sha256-EsGNO0dULWf5Bx6bGrCv2kI2Z8aKH0kRvGiuN23wChQ=";
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
