{ config, lib, pkgs, ... }:
{
  networking.hosts = {
    "127.0.0.1" = [ "localhost" "local.ted.europa.eu" ];
  };
  services.davmail = {
    enable = true;
    url = "https://webmail.arhs-developments.com/owa/";
    config = {
      davmail.mode = "EWS";
      davmail.allowRemote = false;
    };
  };
}
