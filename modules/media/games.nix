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
    steam.enable = lib.mkEnableOption "Steam";
    lutris.enable = lib.mkEnableOption "Lutris";
  };

  config = lib.mkMerge [
    {
      users.users.${config.user.name}.packages = [
        (lib.mkIf cfg.lutris.enable pkgs.lutris)
        (lib.mkIf cfg.lutris.enable pkgs.wine)
        (lib.mkIf (cfg.steam.enable || cfg.lutris.enable) pkgs.protontricks)
      ];
    }
    (lib.mkIf cfg.steam.enable {
      hardware.steam-hardware.enable = true;
      programs.steam = {
        enable = true;
        protontricks.enable = true;
      };
    })
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
