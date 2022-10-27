{ config, lib, pkgs, ... }:
{
  imports = [
    ./../modules/system.nix
    ./../modules/network.nix
    ./../modules/virtualisation.nix
    ./../modules/belgian-eid.nix
  ];

  time.timeZone = lib.mkDefault "Europe/Amsterdam";

  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  console = {
    keyMap = lib.mkDefault "fr";
  };
}
