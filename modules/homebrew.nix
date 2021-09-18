{ pkgs, ... }: {
  homebrew = {
    brewPrefix = "/opt/homebrew/bin";
    enable = true;
    autoUpdate = true;
    cleanup = "zap";
    global = {
      brewfile = true;
      noLock = true;
    };

    taps = [
      "homebrew/core"
      "homebrew/cask"
    ];

    casks = [
      "firefox"
    ];

    masApps = {
      "1Password" = 1333542190;
      "Dato" = 1470584107;
    };
  };
}