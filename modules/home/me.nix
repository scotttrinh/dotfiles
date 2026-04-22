# User configuration module
{ config, lib, ... }:
{
  options = {
    me = {
      username = lib.mkOption {
        type = lib.types.str;
        description = "Your username as shown by `id -un`";
      };
      fullname = lib.mkOption {
        type = lib.types.str;
        description = "Your full name for use in Git config";
      };
      email = lib.mkOption {
        type = lib.types.str;
        description = "Your email for use in Git config";
      };
      gitSigning = {
        enable = lib.mkEnableOption "SSH-based Git commit and tag signing";
        keyFile = lib.mkOption {
          type = lib.types.str;
          default = "${config.home.homeDirectory}/.ssh/id_ed25519";
          description = ''
            Path passed to Git as user.signingkey. Use a private key path for
            file-backed keys, or a .pub path when the private key is only
            available through ssh-agent.
          '';
        };
        publicKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            SSH public key line used to populate allowed_signers for local Git
            signature verification. When set, Git also uses this inline public
            key for SSH signing to avoid depending on filesystem access to a
            .pub file. When null, activation will try to derive it from keyFile.
          '';
        };
        agentSocket = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            SSH agent socket to use for agent-backed commit signing. When set,
            Git SSH signing uses a wrapper around ssh-keygen that exports this
            socket explicitly.
          '';
        };
        agentKeyCommentPattern = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Substring used to select a signing key from ssh-agent when
            publicKey is not pinned explicitly.
          '';
        };
        allowedSignersFile = lib.mkOption {
          type = lib.types.str;
          default = "${config.home.homeDirectory}/.config/git/allowed_signers";
          description = "Path to the allowed signers file used for local Git SSH signature verification.";
        };
        principals = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ config.me.email ];
          description = "Principals written to allowed_signers for local Git signature verification.";
        };
      };
    };
  };
  config = {
    home.username = config.me.username;
  };
}
