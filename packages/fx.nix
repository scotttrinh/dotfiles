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
        hash = "sha256-n8GNXDQpraslTMK2JslnnoZr4mSW4J1764dU9sHFhsk=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-7vDya/QZ0w4Hv8TDROU3TdFw0McR+ZZcsLCK/HTk4/w=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-Df1TIkxezt5gG7jOZJ+E+rbbBaOa+81bOeYJGDP2xNc=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-Eg+pkt+Mr5guF8qenjlmx5Cw0VBIBRHq9ROS5moPC4Q=";
      };
    }.${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.6";

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
