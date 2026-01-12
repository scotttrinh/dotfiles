# See /modules/darwin/* for actual settings
# This file is just *top-level* configuration.
{ flake, lib, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
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
  home-manager.users.scotttrinh = { lib, config, ... }: {
    # Claude Code configuration using z.ai proxy
    claudeCode = {
      enable = true;
      auth = {
        type = "apiKey";
        secret = config.sops.placeholder.claude_code_api_key;
      };
      baseUrl = "https://api.z.ai/api/anthropic";
      model = "opus";
      timeoutMs = 3000000;  # 50 minutes
    };

    # Declare the sops secret for this machine
    sops.secrets.claude_code_api_key = {
      key = "CLAUDE_CODE_API_KEY_FRANNIE";
      mode = "0400";
    };
  };
}
