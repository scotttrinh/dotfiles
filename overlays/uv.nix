# Custom uv overlay to override version and source
final: prev:
let
  rustToolchain = final.rust-bin.stable.latest.default;
  customRustPlatform = final.makeRustPlatform {
    cargo = rustToolchain;
    rustc = rustToolchain;
  };
  pkgsWithNewRust = prev.extend (final': prev': { rustPlatform = customRustPlatform; });
in {
  uv = pkgsWithNewRust.uv.overrideAttrs (oldAttrs: rec {
    version = "0.8.22";
    
    src = prev.fetchFromGitHub {
      owner = "astral-sh";
      repo = "uv";
      rev = version;
      hash = "sha256-7/WOjsyfkDTZLNJY0+rNdRUmMabJsSFvKi2yh/WqViQ=";
    };

    cargoDeps = customRustPlatform.fetchCargoVendor {
      inherit src;
      hash = "sha256-RubSyxQjWlkoHMItYLjiyJ5Whz3oMXgioqbuewi1fcM=";
    };
  });
}
