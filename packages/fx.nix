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
        hash = "sha256-nkiXyy4J/ff5qhN1lOZCZNLX5Buy30bpVZ9882vkk3s=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-l+ev5AQ7uzSQoiveA+JhEMHii25pBZvaN2vkrdw8kzE=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-FvszMN5PKHTlf7d3hC57bEEyyp2xw9l9Vf/8XnRSxA4=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-34pcBuCkmpQ3RXrfE/izj/EaNnmkYxBc8yv3V6s3p2E=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.8";
  rev = "e8aa9133417f8b8d5228ceb1ba64cc74dad33db1";

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
