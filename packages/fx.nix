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
        hash = "sha256-coTQXVLnn7keE1mF8Px46Vh3C6p0i3wSjonUktMU6LY=";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256-C9TBJlDQ4idEui6CTJcqkiqd/Ed2nS5DB52uFbT57Tk=";
      };
      aarch64-linux = {
        name = "linux-aarch64";
        hash = "sha256-dtinVCEKTq8gRwhQ81KZwNJI3GD7+9TdbsRkPcpMEsw=";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256-szKnF7ERxBYflu0Y7PiKPlbYkhIZJtpuYH6pU2FHtJA=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "fx is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.14";
  rev = "ae687a4879166088c15d30f2bd6ccc2e6a95e208";

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
