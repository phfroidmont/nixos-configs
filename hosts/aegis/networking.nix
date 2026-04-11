{ lib, ... }:
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
      externalInterface = lib.mkForce null;
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

  boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkForce 1;
}
