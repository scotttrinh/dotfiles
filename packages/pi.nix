{ pkgs }:

pkgs.writeShellScriptBin "pi" ''
  # This sets the cache dir to a user-writable location so it works outside /nix/store
  export UV_CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/uv"

  # Run the tool using uvx, allowing it to download the wheel and deps at runtime
  exec ${pkgs.uv}/bin/uvx --pre pi@latest "$@"
''
