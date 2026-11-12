{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm,
  pnpmConfigHook,
  nodejs,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "zcode-acp";
  version = "0.83.3";

  src = fetchFromGitHub {
    owner = "william0wang";
    repo = "zcode-acp";
    tag = "v${finalAttrs.version}";
    hash = "sha256-7J1ePnwGGuLbUzUuJD6LW2BvUAk/My+YCFIh7EKEsgs=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 3;
    hash = "sha256-fLmBCWuz0vj4g8FZwXbFnzO1gxTtG0HP1bgBbLh5XIQ=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild
    pnpm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/zcode-acp $out/bin
    cp -r dist node_modules package.json $out/lib/zcode-acp/

    makeWrapper ${nodejs}/bin/node $out/bin/zcode-acp \
      --add-flags $out/lib/zcode-acp/dist/cli.js \
      --prefix PATH : ${lib.makeBinPath [ nodejs ]} \
      --set-default ZCODE_ACP_SHOW_COMPLETION_STATUS 0
    makeWrapper ${nodejs}/bin/node $out/bin/zcode-acp-server \
      --add-flags $out/lib/zcode-acp/dist/cli.js \
      --add-flags server \
      --prefix PATH : ${lib.makeBinPath [ nodejs ]} \
      --set-default ZCODE_ACP_SHOW_COMPLETION_STATUS 0
    runHook postInstall
  '';

  meta = {
    description = "ACP (Agent Client Protocol) adapter for ZCode / GLM";
    homepage = "https://github.com/william0wang/zcode-acp";
    license = lib.licenses.mit;
    mainProgram = "zcode-acp";
    platforms = lib.platforms.all;
  };
})
