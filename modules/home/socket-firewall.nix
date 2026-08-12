{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.socketFirewall;
  inherit (cfg) host keychainAccount;

  keychainServiceB64 = "socket-firewall:${host}:auth-b64";
  keychainServicePassword = "socket-firewall:${host}:password";

  envHelperPath = "${config.home.homeDirectory}/.config/socket-firewall/env.sh";
  netrcTemplatePath = "${config.home.homeDirectory}/.config/socket-firewall/netrc.template";
  netrcPath = "${config.home.homeDirectory}/.config/socket-firewall/netrc";

  # Nix-managed netrc *template*: lives in the world-readable Nix store, so it
  # must never contain the credential. @SOCKET_PASSWORD@ is a literal token
  # substituted at shell startup (see envHelperText), mirroring how init's
  # ~/.npmrc defers to $SOCKET_PASSWORD_B64 instead of baking in a secret.
  #
  # netrc needs the *plaintext* password, not the base64 form npm's `_password`
  # field wants, so the expansion step decodes SOCKET_PASSWORD_B64. Token
  # substitution (not envsubst) keeps the plaintext out of the environment.
  netrcPasswordToken = "@SOCKET_PASSWORD@";
  netrcTemplateText = ''
    machine ${host}
      login ${cfg.username}
      password ${netrcPasswordToken}
  '';

  # Mirrors socket-firewall-init.sh write_socket_env_helper (+ UV preview flag
  # present on the triangle endpoint after init). Package-manager config files
  # (npmrc/pip/uv/go) stay unmanaged so tools like `pnpm login` can write them.
  envHelperText = ''
    # Source this file before using npm, pnpm, or bun with Socket Firewall.
    # Preserve credentials inherited from the shell that launched Codex. Its
    # Seatbelt sandbox cannot query Keychain, but it can use inherited values.
    if [ -z "''${SOCKET_AUTH_B64:-}" ] && [ -z "''${CODEX_SANDBOX:-}" ]; then
      if socket_auth_b64="$(security find-generic-password -a "${keychainAccount}" -s "${keychainServiceB64}" -w)"; then
        export SOCKET_AUTH_B64="$socket_auth_b64"
      fi
      unset socket_auth_b64
    fi

    if [ -z "''${SOCKET_PASSWORD_B64:-}" ] && [ -z "''${CODEX_SANDBOX:-}" ]; then
      if socket_password="$(security find-generic-password -a "${keychainAccount}" -s "${keychainServicePassword}" -w)"; then
        export SOCKET_PASSWORD_B64="$(printf '%s' "$socket_password" | base64)"
      fi
      unset socket_password
    fi

    export UV_PREVIEW_FEATURES=native-auth

    # pip (and anything else using vendored requests) reads netrc before
    # keyring, which sidesteps pip.conf's `keyring-provider = subprocess`
    # needing a `keyring` binary that isn't installed. uv authenticates fine on
    # its own via native-auth; this is only for pip-internal tools (vendoring).
    #
    # Expand the Nix-managed template into a 0600 file outside the store.
    # Rewritten whenever the template or Keychain value changes, so MDM
    # credential rotation is picked up on the next new shell.
    if [ -n "''${SOCKET_PASSWORD_B64:-}" ] && [ -f "${netrcTemplatePath}" ]; then
      if socket_netrc_pw="$(printf '%s' "''${SOCKET_PASSWORD_B64}" | base64 -d 2>/dev/null)" \
        && [ -n "$socket_netrc_pw" ]; then
        socket_netrc_new="$(sed "s|${netrcPasswordToken}|$socket_netrc_pw|" "${netrcTemplatePath}")"
        if [ "$socket_netrc_new" != "$(cat "${netrcPath}" 2>/dev/null)" ]; then
          (
            umask 077
            printf '%s\n' "$socket_netrc_new" > "${netrcPath}"
          )
        fi
        export NETRC="${netrcPath}"
      fi
      unset socket_netrc_pw socket_netrc_new
    fi
  '';
in
{
  options.socketFirewall = {
    enable = lib.mkEnableOption "Socket Firewall shell env integration (Keychain-backed auth exports)";

    host = lib.mkOption {
      type = lib.types.str;
      default = "registry.k8s.vercel-security.com";
      description = "Socket Firewall hostname (no scheme); used for Keychain service names.";
    };

    keychainAccount = lib.mkOption {
      type = lib.types.str;
      default = config.home.username;
      description = "macOS Keychain account attribute used by socket-firewall-init.";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = "client-gate";
      description = ''
        Registry username paired with the Keychain password. Matches the
        username init writes into ~/.npmrc and the index URLs in
        ~/.config/{pip/pip.conf,uv/uv.toml}.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isDarwin;
        message = "socketFirewall only supports macOS Keychain-backed credentials.";
      }
    ];

    # Replaces the init script's configure_shell_source append to ~/.zshenv,
    # which conflicts with home-manager's managed ~/.zshenv symlink.
    # Audit checks that ~/.zshenv references this env helper path.
    programs.zsh.envExtra = lib.mkAfter ''
      # Socket Firewall (managed by home-manager; do not let MDM append to ~/.zshenv)
      [ -f "${envHelperPath}" ] && source "${envHelperPath}"
    '';

    home.file.".config/socket-firewall/env.sh".text = envHelperText;

    # Secret-free by construction; the rendered ~/.config/socket-firewall/netrc
    # is written at runtime by env.sh and is deliberately not managed here.
    home.file.".config/socket-firewall/netrc.template".text = netrcTemplateText;

    # Keychain credentials are populated by MDM init and read at shell runtime
    # via env.sh. Do not probe Keychain during home-manager activation: that
    # path often lacks the user's Aqua/login-keychain session, so
    # `security find-generic-password` false-negatives even when entries exist.
  };
}
