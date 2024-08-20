{ config, lib, ... }:

let
  cfg = config.modules.services.languagetool;
in
{
  options.modules.services.languagetool = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {
    services.languagetool = {
      enable = true;
      allowOrigin = "*";
    };
  };
}
