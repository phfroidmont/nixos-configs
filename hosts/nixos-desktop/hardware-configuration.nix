{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "ahci"
      "usbhid"
      "sd_mod"
    ];
    initrd.kernelModules = [ "amdgpu" ];

    kernelModules = [ "kvm-amd" ];
    extraModulePackages = [ ];
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/f1e21558-88e6-413e-b56a-04e0b25e9ddd";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/CCD1-0415";
      fsType = "vfat";
    };

    "/home/froidmpa/Nextcloud" = {
      device = "/dev/disk/by-uuid/a4ba8b21-ea33-4487-b6f6-9bb7470a0acb";
      fsType = "ext4";
    };

    "/home/froidmpa/Backup" = {
      device = "/dev/disk/by-uuid/7fdc4e44-ecb4-49c7-9fb0-cb1ef6235b05";
      fsType = "ext4";
    };
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/f714775c-b5af-4c0c-8330-999b43db4794"; } ];

  zramSwap.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  nix.settings.max-jobs = lib.mkDefault 16;
  networking.useNetworkd = true;
  networking.interfaces.enp31s0.useDHCP = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      rocmPackages.clr
      amdvlk
    ];
  };

  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  services.resolved.dnssec = "false";
}
