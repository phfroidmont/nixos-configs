{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.media.mopidy;
in
{
  options.modules.media.mopidy = {
    enable = lib.my.mkBoolOpt false;
  };
  config = lib.mkIf cfg.enable {
    home-manager.users.${config.user.name} =
      { ... }:
      {
        services.mopidy = {
          enable = true;
          extensionPackages = with pkgs; [
            mopidy-mpd
            mopidy-subidy
          ];
          settings = {
            mpd = {
              enabled = true;
              hostname = "0.0.0.0";
              port = "6600";
            };
            subidy = {
              url = "https://cloud.banditlair.com/apps/music/subsonic";
              username = "paultrial";
              password = "oEcMsam5uo8k";
              legacy_auth = true;
            };
          };
        };
      };
  };
}
