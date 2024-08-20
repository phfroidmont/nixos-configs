{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.services.libvirt;
in
{
  options.modules.services.libvirt = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {

    virtualisation = {
      libvirtd.enable = true;
      spiceUSBRedirection.enable = true;
    };

    users.users.${config.user.name}.extraGroups = [ "libvirtd" ];

    environment.systemPackages = with pkgs; [ virt-manager ];
  };
}
