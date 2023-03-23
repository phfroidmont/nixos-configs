{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.media.emulators;
in {
  options.modules.media.emulators = {
    psx.enable = mkBoolOpt false; # Playstation
    ds.enable = mkBoolOpt false; # Nintendo DS
    gc.enable = mkBoolOpt false; # GameCube
    gb.enable = mkBoolOpt false; # GameBoy + GameBoy Color
    gba.enable = mkBoolOpt false; # GameBoy Advance
    snes.enable = mkBoolOpt false; # Super Nintendo
  };

  config = {
    user.packages = with pkgs; [
      (mkIf cfg.psx.enable epsxe)
      (mkIf cfg.ds.enable desmume)
      (mkIf cfg.gc.enable dolphinEmu)
      (mkIf (cfg.gba.enable || cfg.gb.enable || cfg.snes.enable) higan)
    ];
  };
}
