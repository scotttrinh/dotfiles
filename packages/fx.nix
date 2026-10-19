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
        hash = "sha256-9cQeSANSMSmx9D3XVfXvpgCz6sTg5fIf1oiiB7C0q0M=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-S5ZjzAdvjHMJSeAIuKgLIwom+hZqi90QKN/TSOClWGk=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-EkvM0X31wOH91wTGmRO4E8FLfU/2OFUXCeIR4ekRAlI=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-rVt/62ZAJmcUhFPRo1kFXfezTRyTsyqGUWpQTonzkOk=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.14";
  rev = "66c5103d1e184861bec0f6631998b4824c58f001";

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
