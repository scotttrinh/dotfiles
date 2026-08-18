{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  buildPackages,
  versionCheckHook,
  nix-update-script,
}:

let
  platform =
    {
      aarch64-darwin = {
        name = "aarch64-apple-darwin";
        hash = "sha256-Bh/wcMgwvYLJYMVTUuD0vOBdkJO0Tv2hauL+7uoAMqU=";
      };
      x86_64-darwin = {
        name = "x86_64-apple-darwin";
        hash = "sha256-iOHjRNj4bwX3BBojO1jZOm/3qwgCMmEaXePqUh8Y2DM=";
      };
      # Static musl builds run anywhere, including NixOS, without patchelf.
      aarch64-linux = {
        name = "aarch64-unknown-linux-musl";
        hash = "sha256-Ljzs8jx8D0emx7xrkTWX93AUUs6eCB3xeCpG367zY1U=";
      };
      x86_64-linux = {
        name = "x86_64-unknown-linux-musl";
        hash = "sha256-Cg+AJcrDN79JOfZf6k9xZS2OKiurEsOi5FsVvN0b5iY=";
      };
    }.${stdenvNoCC.hostPlatform.system}
      or (throw "ty is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ty";
  version = "0.0.72";

  src = fetchurl {
    url = "https://github.com/astral-sh/ty/releases/download/${finalAttrs.version}/ty-${platform.name}.tar.gz";
    inherit (platform) hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = [ installShellFiles ];

  installPhase = ''
    runHook preInstall

    install -Dm755 ty-${platform.name}/ty "$out/bin/ty"

    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  postInstall = lib.optionalString (stdenvNoCC.hostPlatform.emulatorAvailable buildPackages) (
    let
      emulator = stdenvNoCC.hostPlatform.emulator buildPackages;
    in
    ''
      installShellCompletion --cmd ty \
        --bash <(${emulator} $out/bin/ty generate-shell-completion bash) \
        --fish <(${emulator} $out/bin/ty generate-shell-completion fish) \
        --zsh <(${emulator} $out/bin/ty generate-shell-completion zsh)
    ''
  );

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Extremely fast Python type checker and language server, written in Rust";
    homepage = "https://github.com/astral-sh/ty";
    changelog = "https://github.com/astral-sh/ty/blob/${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "ty";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = with lib.maintainers; [
      bengsparks
      figsoda
      GaetanLepage
    ];
  };
})
