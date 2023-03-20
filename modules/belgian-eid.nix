{ config, lib, pkgs, ... }:
{
  services.pcscd.enable = true;
  environment.systemPackages = with pkgs.unstable; [
    eid-mw
  ];
}
