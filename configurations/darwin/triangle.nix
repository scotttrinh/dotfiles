# See /modules/darwin/* for actual settings
# This file is just *top-level* configuration.
{ flake, lib, pkgs, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;

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
  home-manager.users.scotttrinh = { lib, config, ... }: {
    home.packages = with pkgs; [
      git-lfs
      gh
    ];

    # Declare the sops secret for this machine
    sops.secrets.claude_code_auth_token = {
      key = "CLAUDE_CODE_AUTH_TOKEN_TRIANGLE";
      mode = "0400";
    };

    claudeCode = {
      enable = true;
      auth = {
        type = "oauth";
        secret = config.sops.placeholder.claude_code_auth_token;
      };
      baseUrl = "https://ai-gateway.vercel.sh";
      model = "opus";
      timeoutMs = 3000000;  # 50 minutes
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
    casks = [
      "1password"
      "slack"
      "cursor"
      "orbstack"
    ];
    brews = [
      "vercel-cli"
      "supabase"
    ];
  };
}
