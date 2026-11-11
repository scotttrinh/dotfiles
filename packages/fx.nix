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
        hash = "sha256-w41A0rZr7szTknKrJag+7FQGqdL3pYtflvZPF/k0gYQ=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-7vQ6Gz+vs48mz/Z0pHbmqji7oKu6ULGYQyaUarD62jk=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-BoeIx5Ua/AsMoNGXwARO9ESSiS1yWdOs+SgqaVZbk8I=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-Cawi9iInkJg87OJk3WvsfRVMtudkjjbbXj0m1NRWuKc=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.16";
  rev = "cf7a7754f443cd9a1d295a60dbbcb913e933c20c";

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
