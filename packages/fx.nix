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
        hash = "sha256-OVrDgy9vbCMfa6eka6bscO763baGYub9bE+44NbXL1k=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-QdPCzXi9tTqp3xb71a6UFcii4+iFHr5kI9sMwyEov3w=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-mQWlHCE9G3/jtQefAP0+YfLbpb3nBzl5kelTXEpwDK8=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-vpQoY2r7EZbLZitI7Ve77TuV58N/K8eEngLAlg+uHwE=";
      };
    }.${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.4";

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
