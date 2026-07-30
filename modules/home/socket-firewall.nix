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

  # Mirrors socket-firewall-init.sh write_socket_env_helper (+ UV preview flag
  # present on the triangle endpoint after init). Package-manager config files
  # (npmrc/pip/uv/go) stay unmanaged so tools like `pnpm login` can write them.
  envHelperText = ''
    # Source this file before using npm, pnpm, or bun with Socket Firewall.
    export SOCKET_AUTH_B64="$(security find-generic-password -a "${keychainAccount}" -s "${keychainServiceB64}" -w)"
    export SOCKET_PASSWORD_B64="$(security find-generic-password -a "${keychainAccount}" -s "${keychainServicePassword}" -w | tr -d '\n' | base64)"
    export UV_PREVIEW_FEATURES=native-auth
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

    # Keychain credentials are populated by MDM init and read at shell runtime
    # via env.sh. Do not probe Keychain during home-manager activation: that
    # path often lacks the user's Aqua/login-keychain session, so
    # `security find-generic-password` false-negatives even when entries exist.
  };
}
