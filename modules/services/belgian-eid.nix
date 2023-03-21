{ config, lib, pkgs, ... }:

with lib;
with lib.my;

let cfg = config.modules.services.belgian-eid;
in {
  options.modules.services.belgian-eid = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {

    nixpkgs.overlays = [
      (final: prev: {
        firefox = prev.firefox.override { pkcs11Modules = [ prev.eid-mw ]; };
      })
    ];

    services.pcscd.enable = true;

    environment.systemPackages = with pkgs.unstable; [ eid-mw ];
  };
}
