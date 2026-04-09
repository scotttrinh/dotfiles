{ flake, pkgs }:

let
  rustToolchain = flake.inputs.rust-overlay.packages.${pkgs.system}.rust_1_92_0;
  rustPlatform = pkgs.makeRustPlatform {
    cargo = rustToolchain;
    rustc = rustToolchain;
  };
in
pkgs.callPackage
  (
    {
      fetchFromGitHub,
      lib,
      rustPlatform,
      stdenv,
      versionCheckHook,
      installShellFiles,
      buildPackages,
      python3Packages,
      nix-update-script,
      rust-jemalloc-sys,
    }:

    rustPlatform.buildRustPackage (finalAttrs: {
      pname = "uv";
      version = "0.11.6";

      src = fetchFromGitHub {
        owner = "astral-sh";
        repo = "uv";
        tag = finalAttrs.version;
        hash = "sha256-S3D8KjIyUw9cy+y8FCNX4o2CezWWBS1c00f6bLytTrE=";
      };

      cargoHash = "sha256-1zKhePStJQx8OiRJo7omJn1w0UdQ9at0c1glsjFPuTo=";

      buildInputs = [ rust-jemalloc-sys ];

      nativeBuildInputs = [ installShellFiles ];

      cargoBuildFlags = [
        "--package"
        "uv"
      ];

      doCheck = false;

      postInstall = lib.optionalString (stdenv.hostPlatform.emulatorAvailable buildPackages) (
        let
          emulator = stdenv.hostPlatform.emulator buildPackages;
        in
        ''
          installShellCompletion --cmd uv \
            --bash <(${emulator} $out/bin/uv generate-shell-completion bash) \
            --fish <(${emulator} $out/bin/uv generate-shell-completion fish) \
            --zsh <(${emulator} $out/bin/uv generate-shell-completion zsh)
        ''
      );

      nativeInstallCheckInputs = [ versionCheckHook ];
      versionCheckProgramArg = "--version";
      doInstallCheck = true;

      passthru = {
        tests.uv-python = python3Packages.uv;
        updateScript = nix-update-script { };
      };

      meta = {
        description = "Extremely fast Python package installer and resolver, written in Rust";
        longDescription = ''
          `uv` manages project dependencies and environments, with support for lockfiles, workspaces, and more.

          Due to `uv`'s (over)eager fetching of dynamically-linked Python executables,
          as well as vendoring of dynamically-linked libraries within Python modules distributed via PyPI,
          NixOS users can run into issues when managing Python projects.
          See the Nixpkgs Reference Manual entry for `uv` for information on how to mitigate these issues:
          https://nixos.org/manual/nixpkgs/unstable/#sec-uv.

          For building Python projects with `uv` and Nix outside of nixpkgs, check out `uv2nix` at https://github.com/pyproject-nix/uv2nix.
        '';
        homepage = "https://github.com/astral-sh/uv";
        changelog = "https://github.com/astral-sh/uv/blob/${finalAttrs.version}/CHANGELOG.md";
        license = with lib.licenses; [
          asl20
          mit
        ];
        maintainers = with lib.maintainers; [
          bengsparks
          GaetanLepage
          prince213
        ];
        mainProgram = "uv";
        broken = stdenv.buildPlatform.is32bit;
      };
    })
  )
  { inherit rustPlatform; }
