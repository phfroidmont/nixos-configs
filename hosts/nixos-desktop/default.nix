{ pkgs, config, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/base.nix
    ../../users
  ];

  # Allow to externally control MPD
  networking.firewall.allowedTCPPorts = [ 6600 ];

  system.stateVersion = "19.09";
}
