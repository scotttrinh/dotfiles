{ input
, system
,
}:
let
  packages = input.packages.${system};
  names = [
    "amp"
    "antigravity-cli"
    "claude-code"
    "codex"
    "codex-acp"
    "mimo-code"
    "omp"
    "opencode"
  ];
in
{
  revision = input.rev;
  packages = builtins.listToAttrs (
    map
      (name: {
        inherit name;
        value = packages.${name}.version;
      })
      names
  );
}
