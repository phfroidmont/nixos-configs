{ config, lib, pkgs, ... }:
{
  imports = [
    ./../modules/system.nix
    ./../modules/network.nix
    ./../modules/virtualisation.nix
    ./../modules/belgian-eid.nix
    ./../modules/games.nix
  ];

  time.timeZone = lib.mkDefault "Europe/Amsterdam";

  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  console = {
    font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";
    keyMap = lib.mkDefault "fr";
  };
}
