# See /modules/darwin/* for actual settings
# This file is just *top-level* configuration.
{ flake
, lib
, pkgs
, ...
}:

let
  inherit (flake) inputs;
  inherit (inputs) self;
  system = pkgs.stdenv.hostPlatform.system;
  selfPackages = self.packages.${system};
  onePasswordSigningPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMKUljVm2Oqpt2ooRpDncG3pgbaS5IJ3TMrb5d21zgL4 scott@scotttrinh.com";

  # Define work repos to clone and setup
  # Each entry: { url, path, postClone (optional) }
  workRepos = [
    {
      url = "https://github.com/vercel/front";
      path = "$HOME/github.com/vercel/front";
      postClone = "pnpm install";
    }
  ];

  # Generate the activation script for cloning repos
  cloneRepoScript = repo: ''
    if [ ! -d "${repo.path}" ]; then
      echo "Cloning ${repo.url} to ${repo.path}..."
      mkdir -p "$(dirname "${repo.path}")"
      ${pkgs.git}/bin/git clone "${repo.url}" "${repo.path}" --depth 1
      ${lib.optionalString (repo ? postClone) ''
        echo "Running post-clone commands for ${repo.path}..."
        cd "${repo.path}" && ${repo.postClone}
      ''}
    else
      echo "Repository ${repo.path} already exists, skipping..."
    fi
  '';
in
{
  imports = [
    self.darwinModules.default
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  networking.hostName = "triangle";

  system.primaryUser = "scotttrinh";

  # Automatically move old dotfiles out of the way
  #
  # Note that home-manager is not very smart, if this backup file already exists it
  # will complain "Existing file .. would be clobbered by backing up". To mitigate this,
  # we try to use as unique a backup file extension as possible.
  home-manager.backupFileExtension = "nixos-unified-template-backup";

  # Work-specific home-manager configuration
  # This merges with configurations/home/scotttrinh.nix
  home-manager.users.scotttrinh =
    { lib, config, ... }:
    let
      fx = pkgs.writeShellScriptBin "fx" ''
        export AI_GATEWAY_API_KEY="$(tr -d '\r\n' < ${config.sops.secrets.ai_gateway_api_key.path})"
        exec ${lib.getExe selfPackages.fx} "$@"
      '';
    in
    {
      me.gitSigning.publicKey = onePasswordSigningPublicKey;

      # Work laptop only: Socket Firewall shell env (MDM/init owns registry files
      # + Keychain; home-manager only sources the Keychain helper from zshenv
      # so init cannot fight the managed ~/.zshenv symlink).
      socketFirewall.enable = true;
      doomConfig.caldav.enable = true;
      doomConfig.muster.enable = true;

      sops.defaultSopsFile = ../../secrets/triangle.yaml;

      sops.secrets.emacs_authinfo = {
        key = "EMACS_AUTHINFO";
        path = "${config.home.homeDirectory}/.authinfo";
        mode = "0400";
      };

      sops.secrets.ai_gateway_api_key = {
        key = "AI_GATEWAY_API_KEY";
        mode = "0400";
      };

      selectedPackages = {
        fx = selfPackages.fx;
        devbox = selfPackages.devbox;
      };

      home.packages = [
        fx
        config.selectedPackages.devbox
      ];

      claudeCode = {
        enable = true;
        auth = {
          type = "oauth";
          secret = config.sops.placeholder.ai_gateway_api_key;
        };
        baseUrl = "https://ai-gateway.vercel.sh";
        model = "claude-fable-5";
        statusLine.enable = true;
        timeoutMs = 3000000; # 50 minutes
      };

      # Activation script to clone work repos
      # Runs during `nix run .#activate` / `home-manager switch`
      home.activation.cloneWorkRepos = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        echo "Setting up work repositories..."
        ${lib.concatMapStrings cloneRepoScript workRepos}
      '';
    };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  homebrew = {
    masApps = {
      OktaVerify = 490179405;
      Xcode = 497799835;
    };
    casks = [
      "slack"
      "cursor"
      "orbstack"
      "vercel"
    ];
    brews = [
      "supabase"
    ];
  };
}
