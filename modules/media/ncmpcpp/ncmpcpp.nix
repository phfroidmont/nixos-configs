{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.media.ncmpcpp;
in
{
  options.modules.media.ncmpcpp = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${config.user.name} = {

      home = {
        packages = with pkgs; [
          (ncmpcpp.override { visualizerSupport = true; })
          mpc_cli
        ];

        file.".config/ncmpcpp/config".source = ./config;
        file.".config/ncmpcpp/bindings".source = ./bindings;
      };

    };
  };
}
