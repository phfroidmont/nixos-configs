{ inputs, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.media.ncmpcpp;
in {
  options.modules.media.ncmpcpp = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = {

      home = {
        packages = with pkgs.unstable; [
          (ncmpcpp.override { visualizerSupport = true; })
          mpc_cli
        ];

        file.".config/ncmpcpp/config".source = ./config;
        file.".config/ncmpcpp/bindings".source = ./bindings;
      };

    };
  };
}
