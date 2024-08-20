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
    psx.enable = lib.my.mkBoolOpt false; # Playstation
    ds.enable = lib.my.mkBoolOpt false; # Nintendo DS
    gc.enable = lib.my.mkBoolOpt false; # GameCube
    gb.enable = lib.my.mkBoolOpt false; # GameBoy + GameBoy Color
    gba.enable = lib.my.mkBoolOpt false; # GameBoy Advance
    snes.enable = lib.my.mkBoolOpt false; # Super Nintendo
  };

  config = {
    user.packages = [
      (lib.mkIf cfg.psx.enable pkgs.duckstation)
      (lib.mkIf cfg.ds.enable pkgs.desmume)
      (lib.mkIf cfg.gc.enable pkgs.dolphinEmu)
      (lib.mkIf (cfg.gba.enable || cfg.gb.enable || cfg.snes.enable) pkgs.higan)
    ];
  };
}
