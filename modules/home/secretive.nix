{ config, lib, pkgs, ... }:
let
  secretiveAgentSocket =
    "${config.home.homeDirectory}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
in
{
  config = lib.mkIf pkgs.stdenv.isDarwin {
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
      agentSocket = secretiveAgentSocket;
      agentKeyCommentPattern = "GitHub-Commit-Signing@secretive";
      allowedSignersFile = "${config.home.homeDirectory}/.gitallowedsigners";
    };
  };
}
