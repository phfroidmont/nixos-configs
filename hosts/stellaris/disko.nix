{ ... }:
{
  disko.devices = {
    disk.main = {
      type = "disk";
      # Replace with your device, e.g. /dev/disk/by-id/nvme-Samsung_SSD_980_...
      device = "/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_2TB_S7YFNJ0Y612225D";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            type = "ef00";
            size = "512M";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              settings = {
                allowDiscards = true;
              };
              content = {
                type = "btrfs";
                extraArgs = [
                  "-L"
                  "nixos"
                ];
                # Top-level btrfs mountpoint isn't used; subvols below define mounts
                subvolumes = {
                  "@".mountpoint = "/";
                  "@home".mountpoint = "/home";
                  "@nix".mountpoint = "/nix";
                  "@log".mountpoint = "/var/log";
                  "@cache".mountpoint = "/var/cache";

                  # Common, fast, SSD-friendly defaults
                  "@".mountOptions = [
                    "compress=zstd"
                    "noatime"
                    "ssd"
                    "autodefrag"
                  ];
                  "@home".mountOptions = [
                    "compress=zstd"
                    "noatime"
                    "ssd"
                    "autodefrag"
                  ];
                  "@nix".mountOptions = [
                    "compress=zstd"
                    "noatime"
                    "ssd"
                  ];
                  "@log".mountOptions = [
                    "compress=zstd"
                    "noatime"
                    "ssd"
                  ];
                  "@cache".mountOptions = [
                    "compress=zstd"
                    "noatime"
                    "ssd"
                  ];
                };
              };
            };
          };
        };
      };
    };
  };
}
