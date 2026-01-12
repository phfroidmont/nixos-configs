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

    boot.extraModprobeConfig = ''
      options kvm_amd nested=1
      options kvm ignore_msrs=1
    '';

    users.users.${config.user.name}.extraGroups = [ "libvirtd" ];

    environment.systemPackages = with pkgs; [ virt-manager ];
  };
}
