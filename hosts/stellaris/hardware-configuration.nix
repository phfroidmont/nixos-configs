{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/60093dc5-7e4f-479d-8e6b-d4f5fedcb01f";
    fsType = "btrfs";
    options = [ "subvol=@" ];
  };

  boot.initrd.luks.devices."cryptroot".device =
    "/dev/disk/by-uuid/46f38e24-f03e-4e3b-9266-652340e1fa41";

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/4847-A536";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/60093dc5-7e4f-479d-8e6b-d4f5fedcb01f";
    fsType = "btrfs";
    options = [ "subvol=@home" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/60093dc5-7e4f-479d-8e6b-d4f5fedcb01f";
    fsType = "btrfs";
    options = [ "subvol=@nix" ];
  };

  fileSystems."/var/cache" = {
    device = "/dev/disk/by-uuid/60093dc5-7e4f-479d-8e6b-d4f5fedcb01f";
    fsType = "btrfs";
    options = [ "subvol=@cache" ];
  };

  fileSystems."/var/log" = {
    device = "/dev/disk/by-uuid/60093dc5-7e4f-479d-8e6b-d4f5fedcb01f";
    fsType = "btrfs";
    options = [ "subvol=@log" ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      amdgpuBusId = "PCI:6:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
}
