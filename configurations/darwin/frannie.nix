# See /modules/darwin/* for actual settings
# This file is just *top-level* configuration.
{ flake, lib, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
  onePasswordSigningPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOrz5uvnOrXPqo6xcl2o+pWUgEkz4vj9iIZy/sFNBzrp";
in
{
  imports = [
    self.darwinModules.default
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  networking.hostName = "frannie";

  system.primaryUser = "scotttrinh";

  # Automatically move old dotfiles out of the way
  #
  # Note that home-manager is not very smart, if this backup file already exists it
  # will complain "Existing file .. would be clobbered by backing up". To mitigate this,
  # we try to use as unique a backup file extension as possible.
  home-manager.backupFileExtension = "nixos-unified-template-backup";

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # Machine-specific home-manager configuration
  home-manager.users.scotttrinh = { lib, config, pkgs, ... }: {
    doomConfig.caldav.enable = true;

    sops.defaultSopsFile = ../../secrets/frannie.yaml;

    sops.secrets.emacs_authinfo = {
      key = "EMACS_AUTHINFO";
      path = "${config.home.homeDirectory}/.authinfo";
      mode = "0400";
    };

    me.gitSigning.publicKey = onePasswordSigningPublicKey;

    # Claude Code configuration using z.ai proxy
    claudeCode = {
      enable = true;
      model = "opus";
      timeoutMs = 3000000; # 50 minutes
    };

    sops.secrets.ai_gateway_api_key = {
      key = "AI_GATEWAY_API_KEY";
      mode = "0400";
    };

    selectedPackages.fx = self.packages.${pkgs.stdenv.hostPlatform.system}.fx;

    home.packages = [
      (pkgs.writeShellScriptBin "fx" ''
        export AI_GATEWAY_API_KEY="$(cat ${config.sops.secrets.ai_gateway_api_key.path})"
        exec ${lib.getExe config.selectedPackages.fx} "$@"
      '')
    ];

    launchd.agents.antigravity-remote-control = {
      enable = true;
      config = {
        ProgramArguments = [
          (lib.getExe (pkgs.writeShellScriptBin "agy-remote-control" ''
            PORT=4400
            while (( PORT < 4500 )) && (exec 3<>"/dev/tcp/127.0.0.1/''${PORT}") 2>/dev/null; do
              PORT=$((PORT + 1))
            done

            exec ${lib.getExe config.selectedPackages.antigravity-cli} \
              --remote-control \
              --hub-port "$PORT" \
              --remote-control-name "frannie" \
              "$@"
          ''))
        ];
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "${config.home.homeDirectory}/.antigravity/agy_daemon.log";
        StandardErrorPath = "${config.home.homeDirectory}/.antigravity/agy_daemon.log";
        EnvironmentVariables = {
          AGY_CLI_DISABLE_AUTO_UPDATE = "true";
        };
      };
    };
  };
  homebrew = {
    casks = [
      "orbstack"
      "openmtp"
    ];
    brews = [
      "vercel-cli"
    ];
  };
}
