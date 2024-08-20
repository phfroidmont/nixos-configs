{ modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "sdhci_pci"
      ];
      kernelModules = [ "dm-snapshot" ];
    };
    kernelModules = [ "kvm-amd" ];
    # Required, otherwise the kernel freezes on boot
    kernelParams = [
      "amd_iommu=on"
      "iommu=pt"
      "pci=noats"
    ];
    extraModulePackages = [ ];
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    initrd.luks.devices."crypted".device = "/dev/disk/by-uuid/1e900b2e-daea-4558-b18f-3d3a5843de61";
  };

  hardware.cpu.amd.updateMicrocode = true;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/a8abad9b-5615-4887-8431-3d80b78d073e";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/077C-758A";
    fsType = "vfat";
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/bb8fa9ef-9b8f-413d-913a-6c891649a954"; } ];

  zramSwap.enable = true;

  hardware = {
    bluetooth = {
      enable = true;
      # Enable A2DP Sink
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
        };
      };
    };
  };

  networking.networkmanager.enable = true;

  services.blueman.enable = true;

  services.logind.lidSwitch = "ignore";

}
