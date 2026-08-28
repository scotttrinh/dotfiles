{ config, lib, pkgs, ... }:
let
  onePasswordAgentSocket =
    "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
in
{
  options.me.onePassword.enable = lib.mkEnableOption "1Password SSH agent integration" // {
    default = pkgs.stdenv.isDarwin;
  };

  config = lib.mkIf config.me.onePassword.enable {
    home.sessionVariables.SSH_AUTH_SOCK = onePasswordAgentSocket;

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
        IdentityAgent = "\"${onePasswordAgentSocket}\"";
      };
    };

    me.gitSigning.agentSocket = onePasswordAgentSocket;
  };
}
