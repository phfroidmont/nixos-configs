{
  config,
  lib,
  pkgs,
  ...
}:
let
  wanInterface = "enp1s0";
  lanBridge = "br-lan";
  lanInterfaces = [
    "enp2s0"
    "enp3s0"
    "enp4s0"
  ];
in
{
  networking.hostName = "aegis";

  hardware = {
    enableRedistributableFirmware = true;
    wirelessRegulatoryDatabase = true;
  };

  networking = {
    useDHCP = false;
    interfaces.${wanInterface}.useDHCP = true;

    bridges.${lanBridge}.interfaces = lanInterfaces;

    interfaces.${lanBridge}.ipv4.addresses = [
      {
        address = "192.168.1.1";
        prefixLength = 24;
      }
    ];

    nameservers = [
      "127.0.0.1"
      "1.1.1.1"
    ];

    nat = {
      enable = true;
      externalInterface = wanInterface;
      internalInterfaces = [ lanBridge ];
    };

    firewall = {
      enable = true;
      checkReversePath = "loose";
      interfaces.${lanBridge} = {
        allowedTCPPorts = [
          22
          53
          3000
        ];
        allowedUDPPorts = [
          53
          67
        ];
      };
    };
  };

  nix.settings.trusted-users = [
    "root"
    config.user.name
  ];

  services.dnsmasq = {
    enable = true;
    settings = {
      interface = lanBridge;
      port = 54;
      "bind-interfaces" = true;
      "listen-address" = [
        "127.0.0.1"
        "192.168.1.1"
      ];
      "domain-needed" = true;
      "bogus-priv" = true;
      "no-resolv" = true;
      server = [
        "9.9.9.10"
        "1.1.1.1"
      ];
      domain = "lan";
      local = "/lan/";
      "expand-hosts" = true;
      "cache-size" = 1000;
      "dhcp-range" = [ "192.168.1.100,192.168.1.199,255.255.255.0,24h" ];
      "dhcp-option" = [
        "option:router,192.168.1.1"
        "option:dns-server,192.168.1.1"
        "option:domain-search,lan"
      ];
      "dhcp-authoritative" = true;
    };
  };

  services.adguardhome = {
    enable = true;
    openFirewall = false;
    mutableSettings = false;
    settings = {
      http = {
        address = "192.168.1.1:3000";
      };
      auth_attempts = 5;
      block_auth_min = 15;
      dns = {
        bind_hosts = [
          "127.0.0.1"
          "192.168.1.1"
        ];
        port = 53;
        statistics_interval = 365;
        upstream_dns = [
          "tls://doh.mullvad.net"
          "[/lan/]127.0.0.1:54"
          "[//]127.0.0.1:54"
        ];
        local_ptr_upstreams = [ "127.0.0.1:54" ];
        use_private_ptr_resolvers = true;
        resolve_clients = true;
        bootstrap_dns = [ "9.9.9.10" ];
      };
      querylog = {
        enabled = true;
        interval = "8760h";
      };
    };
  };

  services.hostapd = {
    enable = true;
    radios.wlp6s0 = {
      countryCode = "BE";
      band = "2g";
      channel = 6;
      networks.wlp6s0 = {
        ssid = "NSA honeypot";
        authentication.mode = "none";
        settings = {
          bridge = lanBridge;
          wpa = 2;
          wpa_key_mgmt = "WPA-PSK";
          wpa_pairwise = "CCMP";
          rsn_pairwise = "CCMP";
        };
        dynamicConfigScripts."20-wpa-passphrase" = pkgs.writeShellScript "hostapd-wpa-passphrase" ''
          set -euo pipefail

          HOSTAPD_CONFIG="$1"
          PASSFILE="/etc/secrets/aegis-wifi-passphrase"

          if [[ ! -r "$PASSFILE" ]]; then
            echo "missing WPA2 passphrase file: $PASSFILE" >&2
            exit 1
          fi

          passphrase="$(${pkgs.coreutils}/bin/tr -d '\r\n' < "$PASSFILE")"
          if (( ''${#passphrase} < 8 || ''${#passphrase} > 63 )); then
            echo "WPA2 passphrase must be 8..63 characters" >&2
            exit 1
          fi

          printf 'wpa_passphrase=%s\n' "$passphrase" >> "$HOSTAPD_CONFIG"
        '';
      };
    };
  };

  systemd.services.hostapd.unitConfig.ConditionPathExists = "/etc/secrets/aegis-wifi-passphrase";

  boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkForce 1;

  user = {
    name = "admin";
    description = lib.mkForce "Router administrator";
    extraGroups = [ "wheel" ];
    hashedPassword = "!";
    initialPassword = lib.mkForce null;
    openssh.authorizedKeys.keyFiles = [
      ../../ssh_keys/phfroidmont-desktop.pub
      ../../ssh_keys/phfroidmont-stellaris.pub
    ];
  };

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
