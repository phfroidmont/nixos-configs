{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.hardware.audio;
in {
  options.modules.hardware.audio = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    sound.enable = true;

    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      pulse.enable = true;
    };

    home-manager.users.${config.user.name} = {
      home.packages = with pkgs.unstable; [ pulsemixer ];
    };
  };
}
