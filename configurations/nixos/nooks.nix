# NixOS configuration for the nooks OrbStack VM
#
# This VM runs isolated nook containers for AI agent development with wigg + claude-code.
# Bootstrap instructions: see IMPLEMENTATION_PLAN.md
#
{ flake, config, pkgs, lib, modulesPath, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    # LXC container base (required for OrbStack)
    "${modulesPath}/virtualisation/lxc-container.nix"
    # OrbStack-specific settings (DNS, watchdogs, SSH, etc.)
    self.nixosModules.orbstack
    # Nook container infrastructure
    inputs.nook.nixosModules.default
    # SOPS secrets management
    inputs.sops-nix.nixosModules.sops
  ];

  # Platform: aarch64-linux for OrbStack on Apple Silicon
  nixpkgs.hostPlatform = "aarch64-linux";

  networking.hostName = "nooks";

  # User account with UID 501 to match macOS (for OrbStack file sharing)
  users.users.scotttrinh = {
    uid = 501;
    isSystemUser = true;
    group = "users";
    extraGroups = [ "wheel" "orbstack" ];
    createHome = true;
    home = "/home/scotttrinh";
    homeMode = "700";
    useDefaultShell = true;
  };

  security.sudo.wheelNeedsPassword = false;
  users.mutableUsers = false;

  # SSH agent and GitHub configuration
  programs.ssh = {
    startAgent = true;
    extraConfig = ''
      Host github.com
        HostName github.com
        User git
        IdentityFile ~/.ssh/id_ed25519
        AddKeysToAgent yes
    '';
    # GitHub host keys from https://api.github.com/meta
    knownHosts = {
      "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
  };

  # System packages available on the VM host
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    tmux
    htop
    ripgrep
    jq
    # Nook CLI for managing containers
    inputs.nook.packages.${pkgs.system}.nook
  ];

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # =========================================================================
  # SOPS Secrets Configuration
  # =========================================================================
  # The age key is copied from macOS during bootstrap:
  #   cp /mnt/mac/Users/scotttrinh/.config/sops/age/nooks.key ~/.config/sops/age/keys.txt

  sops = {
    defaultSopsFile = ../../secrets.yaml;
    age.keyFile = "/home/scotttrinh/.config/sops/age/keys.txt";

    secrets = {
      anthropic-api-key = {
        key = "ANTHROPIC_API_KEY_NOOKS";
      };
    };
  };

  # =========================================================================
  # Nook Container Configuration
  # =========================================================================

  services.nook = {
    enable = true;
    nookCount = 5;
    user = "scotttrinh";
    group = "users";

    # SSH keys for accessing nooks from the VM host
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBcIvil2JBo19GyGhNkNnoh9eGGP6RSvdS4LrXQKakyI nooks-access"
    ];

    # Note: Nooks don't need SSH access to GitHub. All git push/pull operations
    # happen from the VM host. Nooks only do local git operations (commit, merge, etc.).

    # Extra packages installed in all nook containers (Tier 2: external flakes)
    extraPackages = [
      inputs.llm-agents.packages.${pkgs.system}.claude-code
      inputs.wigg.packages.${pkgs.system}.wigg
    ];

    # Inject ANTHROPIC_API_KEY into all nooks
    secrets.env = {
      ANTHROPIC_API_KEY = config.sops.secrets.anthropic-api-key.path;
    };

    # Settings files copied into all nook containers
    settings.files = {
      # Claude Code configuration
      "/home/nook/.claude/settings.json" = {
        content = builtins.toJSON {
          model = "claude-sonnet-4-20250514";
          permissions = {
            allow = [
              "Bash(git *)"
              "Bash(nix *)"
              "Bash(npm *)"
              "Bash(cargo *)"
            ];
            deny = [ ];
          };
        };
      };

      # Nook-specific context for Claude Code
      "/home/nook/.claude/CLAUDE.md" = {
        content = ''
          # Nook Container Context

          You are running inside an isolated nook container managed by the nook service.

          ## Environment

          - **Container type**: Systemd-nspawn container on NixOS
          - **User**: nook (non-root)
          - **Home directory**: /home/nook
          - **Working directory**: /home/nook/workspace (contains the cloned repository)

          ## Available Tools

          - `wigg` - Autonomous AI development loop CLI
          - `git` - Version control (local operations only)
          - Standard development tools (curl, jq, ripgrep, etc.)

          ## Guidelines

          - The repository is cloned to ~/workspace. Always work from there.
          - Use wigg for autonomous development workflows.
          - Git operations are local only (commit, merge, branch). Push/pull happens from the VM host.
          - The ANTHROPIC_API_KEY environment variable is set.
        '';
      };
    };
  };

  # =========================================================================
  # Network Configuration
  # =========================================================================

  networking = {
    dhcpcd.enable = false;
    useDHCP = false;
    useHostResolvConf = false;
  };

  systemd.network = {
    enable = true;
    networks."50-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };

  time.timeZone = "America/New_York";

  system.stateVersion = "25.05";
}
