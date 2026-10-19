{ config, lib, ... }:

let
  cfg = config.modules.services.languagetool;
in
{
  options.modules.services.languagetool = {
    enable = lib.mkEnableOption "LanguageTool";
  };

  config = lib.mkIf cfg.enable {
    services.languagetool = {
      enable = true;
      allowOrigin = "*";
    };
  };
}
