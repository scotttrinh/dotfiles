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
      settings."*" = {
        ForwardAgent = false;
        AddKeysToAgent = "no";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
        IdentityAgent = secretiveAgentSocket;
      };
    };

    me.gitSigning = {
      agentSocket = lib.mkDefault secretiveAgentSocket;
      agentKeyCommentPattern = lib.mkDefault "GitHub-Commit-Signing@secretive";
      allowedSignersFile = lib.mkDefault "${config.home.homeDirectory}/.gitallowedsigners";
    };
  };
}
