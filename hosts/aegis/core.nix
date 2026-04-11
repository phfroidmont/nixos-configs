{
  config,
  lib,
  ...
}:
{
  networking.hostName = "aegis";

  hardware = {
    enableRedistributableFirmware = true;
    wirelessRegulatoryDatabase = true;
  };

  nix.settings.trusted-users = [
    "root"
    config.user.name
  ];

  user.description = lib.mkForce "Router administrator";
  user.extraGroups = [ "wheel" ];
  user.hashedPassword = "!";
  user.initialPassword = lib.mkForce null;
  user.openssh.authorizedKeys.keyFiles = [
    ../../ssh_keys/phfroidmont-desktop.pub
    ../../ssh_keys/phfroidmont-stellaris.pub
  ];

  users.users.root.hashedPassword = "!";
  users.users.root.initialPassword = lib.mkForce null;
  security.sudo.wheelNeedsPassword = false;

  home-manager.useUserPackages = lib.mkForce false;
  home-manager.users = lib.mkForce { };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.availableKernelModules = [
    "ahci"
    "nvme"
    "xhci_pci"
    "usbhid"
    "sd_mod"
    "igc"
    "r8169"
    "e1000e"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ config.user.name ];
    };
  };

  system.stateVersion = "25.11";
}
