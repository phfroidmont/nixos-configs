{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.media;
in {
  options.modules.media = {
    steam.enable = mkBoolOpt false;
    lutris.enable = mkBoolOpt false;
  };

  config = {
    user.packages = with pkgs; [
      (mkIf cfg.steam.enable steam)
      (mkIf cfg.lutris.enable lutris)
      (mkIf (cfg.steam.enable || cfg.lutris.enable) protontricks)
    ];
  };
}
