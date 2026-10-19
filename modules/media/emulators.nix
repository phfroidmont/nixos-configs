{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.media.emulators;
in
{
  options.modules.media.emulators = {
    gc.enable = lib.my.mkBoolOpt false; # GameCube
  };

  config = {
    users.users.${config.user.name}.packages = [
      (lib.mkIf cfg.gc.enable pkgs.dolphin-emu)
    ];
  };
}
