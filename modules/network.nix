{ config, lib, pkgs, ... }:
{
  networking.hosts = {
    "127.0.0.1" = [ "localhost" "membres.yourcoop.local" ];
  };
  services.resolved.dnssec = "false";
}
