{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.services.docker;
in
{
  options.modules.services.docker = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {

    virtualisation = {
      docker = {
        enable = true;
        autoPrune.enable = true;
        enableOnBoot = lib.mkDefault false;
      };
    };

    users.users.${config.user.name}.extraGroups = [ "docker" ];

    environment.systemPackages = with pkgs; [ docker-compose ];

  };
}
