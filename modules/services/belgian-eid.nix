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
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {

    services.pcscd.enable = true;

    environment.systemPackages = with pkgs; [
      (firefox.override { pkcs11Modules = [ eid-mw ]; })
      eid-mw
    ];
  };
}
