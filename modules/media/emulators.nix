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
    gc.enable = lib.mkEnableOption "the GameCube emulator";
  };

  config = {
    users.users.${config.user.name}.packages = [
      (lib.mkIf cfg.gc.enable pkgs.dolphin-emu)
    ];
  };
}
