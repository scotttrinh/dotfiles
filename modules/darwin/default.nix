# This is your nix-darwin configuration.
# For home configuration, see /modules/home/*
{ flake, ... }:
let
  inherit (flake) inputs;
in
{
  imports = [
    ../nixos/common
    inputs.determinate.darwinModules.default
  ];

  # Let Determinate Nix manage nix.conf
  nix.enable = false;

  # Custom nix settings written to /etc/nix/nix.custom.conf
  determinateNix = {
    enable = true;
    customSettings = {
      extra-substituters = "https://cache.numtide.com";
      extra-trusted-public-keys = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
    };
  };

  # Use TouchID for `sudo` authentication
  security.pam.services.sudo_local.touchIdAuth = true;

  # Raise the default file-descriptor limits for launchd-managed processes.
  launchd.daemons.maxfiles = {
    script = ''
      /usr/bin/true
    '';
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = false;
      SoftResourceLimits.NumberOfFiles = 65536;
      HardResourceLimits.NumberOfFiles = 200000;
    };
  };

  # Configure macOS system
  # More examples => https://github.com/ryan4yin/nix-darwin-kickstarter/blob/main/rich-demo/modules/system.nix
  system = {
    defaults = {
      dock = {
        autohide = true;
        mru-spaces = false;
        static-only = true;
        orientation = "left";
        tilesize = 32;
      };

      screencapture.location = "~/ScreenCaptures";

      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
      };

      NSGlobalDomain = {
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
      };

      finder = {
        _FXShowPosixPathInTitle = true; # show full path in finder title
        AppleShowAllExtensions = true; # show all file extensions
        FXEnableExtensionChangeWarning = false; # disable warning when changing file extension
        QuitMenuItem = true; # enable quit menu item
        ShowPathbar = true; # show path bar
        ShowStatusBar = true; # show status bar
      };
    };

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };
  };

  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    taps = [
      "mas-cli/tap"
    ];
    casks = [
      "1password"
      "ghostty"
      "raycast"
      "opencode-desktop"
      "secretive"
    ];
    brews = [
      "mas-cli/tap/mas"
    ];
    masApps = {
      Dato = 1470584107;
    };
  };
}
