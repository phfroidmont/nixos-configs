{ config, lib, pkgs, ... }:

with lib;
with lib.my;

let cfg = config.modules.services.docker;
in {
  options.modules.services.docker = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {

    virtualisation = {
      docker = {
        enable = true;
        autoPrune.enable = true;
        enableOnBoot = mkDefault false;
      };
    };

    users.users.${config.user.name}.extraGroups = [ "docker" ];

    environment.systemPackages = with pkgs; [ docker-compose ];

  };
}
