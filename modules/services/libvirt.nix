{ config, lib, pkgs, ... }:

with lib;
with lib.my;

let cfg = config.modules.services.libvirt;
in {
  options.modules.services.libvirt = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {

    virtualisation = {
      libvirtd.enable = true;
      spiceUSBRedirection.enable = true;
    };
    users.users.froidmpa.extraGroups = [ "libvirtd" ];

    environment.systemPackages = with pkgs; [ virt-manager ];
  };
}
