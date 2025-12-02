# This is your nix-darwin configuration.
# For home configuration, see /modules/home/*
{
  imports = [
    ../nixos/common
  ];
  nix.enable = false;

  # Use TouchID for `sudo` authentication
  security.pam.services.sudo_local.touchIdAuth = true;

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
      "ghostty"
    ];
    brews = [
      "mas-cli/tap/mas"
    ];
    masApps = {
      Dato = 1470584107;
    };
  };
}
