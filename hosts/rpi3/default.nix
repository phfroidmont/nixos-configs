{ inputs, pkgs, ... }: {

  nix = {
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.kernelParams = [ "cma=256M" ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  swapDevices = [{
    device = "/swapfile";
    size = 1024;
  }];

  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../../ssh_keys/phfroidmont-desktop.pub
    ../../ssh_keys/phfroidmont-laptop.pub
  ];

  services.adguardhome = {
    enable = true;

    host = "0.0.0.0";
    port = 80;
    openFirewall = true;

    mutableSettings = false;

    settings = {
      auth_attempts = 5;
      block_auth_min = 15;
      dns = {
        bind_host = "0.0.0.0";
        port = 53;
        statistics_interval = 90;
        querylog_enabled = true;
        querylog_interval = "2160h";
        upstream_dns =
          [ "tls://doh.mullvad.net" "[/lan/]192.168.1.1" "[//]192.168.1.1" ];
        local_ptr_upstreams = [ "192.168.1.1" ];
        use_private_ptr_resolvers = true;
        resolve_clients = true;
        bootstrap_dns = [ "9.9.9.10" ];
        rewrites = [
          {
            domain = "rpi3";
            answer = "192.168.1.2";
          }
          {
            domain = "rpi3.lan";
            answer = "192.168.1.2";
          }
        ];
      };
    };
  };

  networking.hostName = "rpi3";
  networking.firewall.allowedTCPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  environment.systemPackages = with pkgs; [ vim htop ];

  system.stateVersion = "22.05";
}
