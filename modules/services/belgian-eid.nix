{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.services.belgian-eid;
in
{
  options.modules.services.belgian-eid = {
    enable = lib.mkEnableOption "Belgian eID support";
  };

  config = lib.mkIf cfg.enable {
    services.pcscd.enable = true;
    environment.systemPackages = [ pkgs.eid-mw ];
  };
}
