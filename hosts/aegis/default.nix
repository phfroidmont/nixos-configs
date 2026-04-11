{ ... }:
{
  user.name = "admin";

  imports = [
    ./core.nix
    ./networking.nix
    ./dns-dhcp.nix
    ./wifi.nix
    ./mullvad.nix
  ];
}
