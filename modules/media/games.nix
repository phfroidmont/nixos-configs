{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.media;
in
{
  options.modules.media = {
    steam.enable = lib.my.mkBoolOpt false;
    lutris.enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkMerge [
    {
      user.packages = [
        (lib.mkIf cfg.steam.enable pkgs.steam)
        (lib.mkIf cfg.lutris.enable pkgs.lutris)
        (lib.mkIf cfg.lutris.enable pkgs.wine)
        (lib.mkIf (cfg.steam.enable || cfg.lutris.enable) pkgs.protontricks)
      ];
    }
    (lib.mkIf (cfg.steam.enable || cfg.lutris.enable) {
      programs.gamemode = {
        enable = true;
        enableRenice = true;
      };
      home-manager.users.${config.user.name} = {
        programs.mangohud = {
          enable = true;
        };
      };
    })
  ];
}
