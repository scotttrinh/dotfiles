{ config, lib, pkgs, ... }:
let
  gitSigning = config.me.gitSigning;
  allowedSignersFile = gitSigning.allowedSignersFile;
  configuredPublicKey = if gitSigning.publicKey == null then "" else gitSigning.publicKey;
  configuredAgentSocket = if gitSigning.agentSocket == null then "" else gitSigning.agentSocket;
  configuredAgentKeyCommentPattern =
    if gitSigning.agentKeyCommentPattern == null then "" else gitSigning.agentKeyCommentPattern;
  signingKey =
    if gitSigning.publicKey == null
    then
      if gitSigning.agentSocket != null && gitSigning.agentKeyCommentPattern != null
      then null
      else gitSigning.keyFile
    else "key::${gitSigning.publicKey}";
  principals = lib.concatStringsSep "," gitSigning.principals;
  sshKeygen = lib.getExe' pkgs.openssh "ssh-keygen";
  sshAdd = lib.getExe' pkgs.openssh "ssh-add";
  sshSigningProgram =
    if gitSigning.agentSocket == null
    then sshKeygen
    else pkgs.writeShellScript "git-ssh-keygen-with-agent" ''
      export SSH_AUTH_SOCK=${lib.escapeShellArg gitSigning.agentSocket}
      exec ${sshKeygen} "$@"
    '';
  defaultKeyCommand =
    if gitSigning.agentSocket != null && gitSigning.agentKeyCommentPattern != null
    then pkgs.writeShellScript "git-ssh-default-key" ''
      export SSH_AUTH_SOCK=${lib.escapeShellArg gitSigning.agentSocket}
      wanted=${lib.escapeShellArg gitSigning.agentKeyCommentPattern}

      while IFS= read -r line; do
        case "$line" in
          *"$wanted"*)
            printf 'key::%s\n' "$line"
            exit 0
            ;;
        esac
      done <<EOF
$(${sshAdd} -L 2>/dev/null || true)
EOF

      exit 1
    ''
    else null;
  signingSettings =
    lib.optionalAttrs gitSigning.enable (
      lib.recursiveUpdate
        {
          gpg.ssh.allowedSignersFile = allowedSignersFile;
        }
        (lib.optionalAttrs (defaultKeyCommand != null) {
          gpg.ssh.defaultKeyCommand = toString defaultKeyCommand;
        })
    );
in
{
  # https://nixos.asia/en/git
  programs = {
    git = {
      enable = true;
      signing = lib.mkIf gitSigning.enable {
        format = "ssh";
        key = signingKey;
        signByDefault = true;
        signer = toString sshSigningProgram;
      };
      settings = lib.recursiveUpdate
        {
          user = {
            name = config.me.fullname;
            email = config.me.email;
          };
          init.defaultBranch = "main";
          credential.helper = "manager";
        }
        signingSettings;
      ignores = [
        ".dir-locals.el"
        ".envrc"
        ".DS_Store"
        ".log"
        ".direnv"
        "*~"
        "*.swp"
        ".locals-only"
        ".agent-shell"
      ];
    };
  };

  home.activation = lib.mkIf gitSigning.enable {
    gitAllowedSigners = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      signers_file=${lib.escapeShellArg allowedSignersFile}
      key_file=${lib.escapeShellArg gitSigning.keyFile}
      configured_public_key=${lib.escapeShellArg configuredPublicKey}
      agent_socket=${lib.escapeShellArg configuredAgentSocket}
      key_comment_pattern=${lib.escapeShellArg configuredAgentKeyCommentPattern}
      principals=${lib.escapeShellArg principals}

      mkdir -p "$(dirname "$signers_file")"

      public_key="$configured_public_key"
      if [ -z "$public_key" ] && [ -n "$agent_socket" ] && [ -n "$key_comment_pattern" ]; then
        while IFS= read -r line; do
          case "$line" in
            *"$key_comment_pattern"*)
              public_key="$line"
              break
              ;;
          esac
        done <<EOF
$(SSH_AUTH_SOCK="$agent_socket" ${sshAdd} -L 2>/dev/null || true)
EOF
      fi

      if [ -z "$public_key" ] && [ -f "$key_file" ]; then
        case "$key_file" in
          *.pub)
            public_key="$(cat "$key_file" 2>/dev/null | tr -d '\n' || true)"
            ;;
          *)
            public_key="$(${sshKeygen} -y -f "$key_file" 2>/dev/null || true)"
            ;;
        esac
      fi

      if [ -n "$public_key" ]; then
        printf '%s %s\n' "$principals" "$public_key" > "$signers_file"
        chmod 0644 "$signers_file"
      else
        echo "warning: unable to determine a Git SSH signing public key; set me.gitSigning.publicKey, configure an agent-backed signing key, or ensure $key_file exists" >&2
      fi
    '';
  };
}
