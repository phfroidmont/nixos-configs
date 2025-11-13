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
          (
            (ncmpcpp.override { visualizerSupport = true; })
            # Duplicate fix until it makes its way in unstable
            .overrideAttrs
            (old: {
              configureFlags = old.configureFlags ++ [ (lib.withFeatureAs true "boost" boost.dev) ];
            })
          )
          mpc
        ];

        file.".config/ncmpcpp/config".source = ./config;
        file.".config/ncmpcpp/bindings".source = ./bindings;
      };

    };
  };
}
