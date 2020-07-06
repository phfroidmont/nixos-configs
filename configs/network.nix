{ config, lib, pkgs, ... }:
{
  networking.hosts = {
    "127.0.0.1" = [ "localhost" "local.ted.europa.eu" ];
  };
}
