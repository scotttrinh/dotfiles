{ lib
, stdenvNoCC
, fetchurl
,
}:

let
  platform =
    {
      aarch64-darwin = {
        name = "macos-aarch64";
        hash = "sha256-IVU5XvZMyF6Rtk+C/9V4nLXohycHPxomUzD+4tA7XlU=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-oZVt9eOZWkcxhTO3IfALyhDZCrm6oqRZKKYxi+rVBZI=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-Beo0BLWWFIYWNq9oOHRwJq1ijaPE3vXR/k0Ax823Ku4=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-hnSadgsOww+ezkIQTFe4qbyh32j9oKjJ3h6DvdWahKk=";
      };
    }.${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.3.54";

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
