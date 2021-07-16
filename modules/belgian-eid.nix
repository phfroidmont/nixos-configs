{ config, lib, pkgs, ... }:
{
  services.pcscd.enable = true;
  environment.systemPackages = with pkgs; [
    eid-mw
  ];
}
