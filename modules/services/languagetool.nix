{ config, lib, pkgs, ... }:

with lib;
with lib.my;

let cfg = config.modules.services.languagetool;
in {
  options.modules.services.languagetool = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    services.languagetool = {
      enable = true;
      allowOrigin = "*";
    };
  };
}
