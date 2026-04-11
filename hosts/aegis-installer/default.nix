{
  lib,
  modulesPath,
  pkgs,
  ...
}:

let
  installAegis = pkgs.writeShellScriptBin "install-aegis" ''
    set -euo pipefail

    if [[ "$(id -u)" -ne 0 ]]; then
      exec sudo "$0" "$@"
    fi

    DISK="''${1:-/dev/nvme0n1}"

    if [[ ! -b "$DISK" ]]; then
      echo "Disk '$DISK' not found. Available disks:"
      ${pkgs.util-linux}/bin/lsblk -d -o NAME,SIZE,MODEL,TYPE
      exit 1
    fi

    PART_SEP=""
    if [[ "$DISK" == *"nvme"* || "$DISK" == *"mmcblk"* ]]; then
      PART_SEP="p"
    fi

    BOOT_PART="''${DISK}''${PART_SEP}1"
    ROOT_PART="''${DISK}''${PART_SEP}2"

    echo ""
    echo "About to wipe and install NixOS on: $DISK"
    echo "  - EFI partition: $BOOT_PART"
    echo "  - Root partition: $ROOT_PART"
    echo ""
    read -r -p "Type ERASE to continue: " CONFIRM

    if [[ "$CONFIRM" != "ERASE" ]]; then
      echo "Aborted."
      exit 1
    fi

    ${pkgs.util-linux}/bin/umount -R /mnt >/dev/null 2>&1 || true
    ${pkgs.util-linux}/bin/swapoff -a >/dev/null 2>&1 || true

    ${pkgs.util-linux}/bin/wipefs --all --force "$DISK"

    ${pkgs.parted}/bin/parted --script "$DISK" \
      mklabel gpt \
      mkpart ESP fat32 1MiB 513MiB \
      set 1 esp on \
      mkpart nixos ext4 513MiB 100%

    ${pkgs.dosfstools}/bin/mkfs.fat -F 32 -n EFI "$BOOT_PART"
    ${pkgs.e2fsprogs}/bin/mkfs.ext4 -F -L nixos "$ROOT_PART"

    ${pkgs.util-linux}/bin/mount "$ROOT_PART" /mnt
    ${pkgs.coreutils}/bin/mkdir -p /mnt/boot
    ${pkgs.util-linux}/bin/mount "$BOOT_PART" /mnt/boot

    /run/current-system/sw/bin/nixos-install --root /mnt --flake /etc/nixos-configs#aegis --no-root-password

    ${pkgs.coreutils}/bin/sync
    ${pkgs.util-linux}/bin/umount -R /mnt

    echo ""
    echo "Install complete. Remove the USB stick and reboot."
  '';
in
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  networking.hostName = "aegis-installer";

  user.name = "nixos";
  user.initialPassword = lib.mkForce null;
  users.users.root.initialPassword = lib.mkForce null;

  home-manager.useUserPackages = lib.mkForce false;
  home-manager.users = lib.mkForce { };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  users.users.nixos.openssh.authorizedKeys.keyFiles = [
    ../../ssh_keys/phfroidmont-desktop.pub
    ../../ssh_keys/phfroidmont-stellaris.pub
  ];

  environment.etc."nixos-configs".source = ../../.;

  environment.systemPackages = [
    installAegis
  ];

  system.stateVersion = "25.11";
}
