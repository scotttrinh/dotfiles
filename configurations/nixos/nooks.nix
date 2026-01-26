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

    # SSH keys for accessing nooks (add your public key here)
    authorizedKeys = [
      # TODO: Add SSH public key after generating ~/.ssh/id_ed25519_nooks
    ];

    # Share host SSH keys with nooks for GitHub access
    hostSshPath = "/home/scotttrinh/.ssh";
    githubSshKeyName = "id_ed25519";

    # Extra packages installed in all nook containers (Tier 2: external flakes)
    extraPackages = [
      inputs.llm-agents.packages.${pkgs.system}.claude-code
      inputs.wigg.packages.${pkgs.system}.wigg
    ];

    # Inject ANTHROPIC_API_KEY into all nooks
    secrets.env = {
      ANTHROPIC_API_KEY = config.sops.secrets.anthropic-api-key.path;
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
