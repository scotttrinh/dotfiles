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
        hash = "sha256-AZ2S5K97Z2jcs2cytSa7Qj7p6CSa/oKod9Gww6mSgH0=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-PTnH8N1JbzlOhjLVd9SSQlb4GoW/b4z0Q5NYt/wRGN8=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-g7KINfAU6ArSwNy5evFyUzarfSf4n6Zh7MgwN+Fa+h8=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-aFKYWwnpby+vwdYEpfC+e572PE3caM9zNZsuzsim3wo=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.8";
  rev = "69d0e9610c7958ae2429d3a1ff40a509e3340781";

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
