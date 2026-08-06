{ lib
, stdenvNoCC
, fetchurl
,
}:

let
  platform =
    {
      aarch64-darwin = {
        name = "darwin-arm64";
        hash = "sha256-uEE19iBcUVLxzSIy3IXlfzJfJy+cHVF+iVtEa/nJtQM=";
      };
      x86_64-darwin = {
        name = "darwin-amd64";
        hash = "sha256-GvRrdzvYPQu+ZRbua0cshhoE8efRsrufK1q6o/o/uXQ=";
      };
      aarch64-linux = {
        name = "linux-arm64";
        hash = "sha256-Z6LVKR3O7mUJAp3hBQ4JQUzUi8s10fcLu5h9hpYs2ek=";
      };
      x86_64-linux = {
        name = "linux-amd64";
        hash = "sha256-x0GZzSTBaee5V1Y0GHENRGakyEo8JWeFz/4ZIQ1TLRQ=";
      };
    }.${stdenvNoCC.hostPlatform.system}
      or (throw "devbox is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "devbox";
  # The upstream installer fetches a rolling "latest" binary; we pin the
  # 12-char commit prefix that the S3 bucket also publishes as an immutable
  # asset (devbox-<os>-<arch>-<commit>). Bump with packages/update-devbox.sh.
  version = "284ae2b97005";

  src = fetchurl {
    url = "https://devboxd.s3.us-west-1.amazonaws.com/devbox-${platform.name}-${finalAttrs.version}";
    inherit (platform) hash;
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/devbox"

    runHook postInstall
  '';

  meta = {
    description = "Vercel internal devbox CLI (develop in a Vercel Sandbox)";
    homepage = "https://api.vercel.com/v1/devbox/install.sh";
    license = lib.licenses.unfree;
    mainProgram = "devbox";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})
