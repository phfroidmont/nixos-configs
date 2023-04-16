{ config, lib, pkgs, ... }:

with lib;
with lib.my;

let cfg = config.modules.services.belgian-eid;
in {
  options.modules.services.belgian-eid = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {

    services.pcscd.enable = true;

    environment.systemPackages = with pkgs.unstable; [
      (firefox.override { pkcs11Modules = [ eid-mw ]; })
      eid-mw
    ];
  };
}
