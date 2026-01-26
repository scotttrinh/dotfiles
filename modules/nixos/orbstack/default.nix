# OrbStack-specific NixOS configuration
#
# This module contains settings required for running NixOS in OrbStack.
# Import this module in any NixOS configuration that runs inside OrbStack.
#
# Based on: agent-cloud/examples/orbstack-host/orbstack.nix

{ lib, config, ... }:

{
  # Add OrbStack CLI tools to PATH
  environment.shellInit = ''
    . /opt/orbstack-guest/etc/profile-early

    # add your customizations here

    . /opt/orbstack-guest/etc/profile-late
  '';

  # Enable documentation
  documentation.man.enable = true;
  documentation.doc.enable = true;
  documentation.info.enable = true;

  # Disable systemd-resolved - OrbStack provides DNS
  services.resolved.enable = false;
  environment.etc."resolv.conf".source = "/opt/orbstack-guest/etc/resolv.conf";

  # Faster DHCP - OrbStack uses SLAAC exclusively
  networking.dhcpcd.extraConfig = ''
    noarp
    noipv6
  '';

  # Disable sshd on host (use OrbStack's SSH)
  services.openssh.enable = false;

  # systemd watchdog adjustments for container environment
  systemd.services."systemd-oomd".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-userdbd".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-udevd".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-timesyncd".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-timedated".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-portabled".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-nspawn@".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-machined".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-localed".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-logind".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-journald@".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-journald".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-journal-remote".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-journal-upload".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-importd".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-hostnamed".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-homed".serviceConfig.WatchdogSec = 0;
  systemd.services."systemd-networkd".serviceConfig.WatchdogSec = lib.mkIf config.systemd.network.enable 0;

  # SSH config for OrbStack tools
  programs.ssh.extraConfig = ''
    Include /opt/orbstack-guest/etc/ssh_config
  '';

  # Support emulated architectures (x86_64 on Apple Silicon)
  nix.settings.extra-platforms = [
    "x86_64-linux"
    "i686-linux"
  ];

  # OrbStack group
  users.groups.orbstack.gid = 67278;
}
