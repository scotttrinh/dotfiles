{ config, pkgs, lib, ... }:
{
  nix.package = pkgs.nix;

  # Dynamically configure GitHub access token via `gh auth token` on activation
  # and write it to ~/.config/nix/nix.conf
  nix.extraOptions = ''
    !include nix.custom.conf
  '';

  home.activation.setupNixGithubAccessToken = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "$HOME/.config/nix"
    custom_conf="$HOME/.config/nix/nix.custom.conf"
    gh_token=""
    if [ -x "${pkgs.gh}/bin/gh" ]; then
      gh_token=$(${pkgs.gh}/bin/gh auth token 2>/dev/null || true)
    elif command -v gh >/dev/null 2>&1; then
      gh_token=$(gh auth token 2>/dev/null || true)
    fi

    if [ -n "$gh_token" ]; then
      $VERBOSE_ECHO "Writing GitHub access token to $custom_conf"
      if [ -z "$DRY_RUN_CMD" ]; then
        printf "access-tokens = github.com=%s\n" "$gh_token" > "$custom_conf"
        chmod 0600 "$custom_conf"
      else
        $DRY_RUN_CMD printf "access-tokens = github.com=%s\n" "<token>" ">" "$custom_conf"
      fi
    else
      $VERBOSE_ECHO "No gh token found; creating empty $custom_conf"
      if [ -z "$DRY_RUN_CMD" ]; then
        : > "$custom_conf"
        chmod 0600 "$custom_conf"
      fi
    fi
  '';
}
