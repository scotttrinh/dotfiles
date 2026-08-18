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
        hash = "sha256-pEDfWSjWuDDSnoZ5DBeNMID+8+B6tzZbdk05m1MwujE=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-w/JivtLfyLSkRJL/POwYUOyIeZqTGxGxSrxOiV+SW2k=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-Md4JbIZYatTpLSi3qKSqPhQqK0E6oKAgkdLqWcESjAU=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-LX9XhBR80FESAHuqgqWhs9ubn/U3aeR8k+gDwieccxc=";
      };
    }.${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.2";

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
