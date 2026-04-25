{ config, lib, pkgs, ... }:
let
  secretiveAgentSocket =
    "${config.home.homeDirectory}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
in
{
  options.me.secretive = {
    enable = lib.mkEnableOption "Secretive SSH agent integration" // {
      default = pkgs.stdenv.isDarwin;
    };
  };

  config = lib.mkIf config.me.secretive.enable {
    home.sessionVariables.SSH_AUTH_SOCK = secretiveAgentSocket;

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks."*" = {
        forwardAgent = false;
        addKeysToAgent = "no";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
        identityAgent = secretiveAgentSocket;
      };
    };

    me.gitSigning = {
      agentSocket = lib.mkDefault secretiveAgentSocket;
      agentKeyCommentPattern = lib.mkDefault "GitHub-Commit-Signing@secretive";
      allowedSignersFile = lib.mkDefault "${config.home.homeDirectory}/.gitallowedsigners";
    };
  };
}
