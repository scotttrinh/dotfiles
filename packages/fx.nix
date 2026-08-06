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
        hash = "sha256-8ms+HoU52fdKrubWn6c+qHSZmOJzcAFmGZN1vVMUBwg=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-0QxNc0qpVHsfCQAQlpjnouVXymVE0wjj/6QzmL+yDKE=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-q1yeaLQWMQemaUfl0S68MzCXlNdqVecrtC3QBaEO6k0=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-/p0QBcVTPnosk1VHUbMQpqUzCqOqyUbSs1CrZxgpdTc=";
      };
    }.${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.3.70";

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
