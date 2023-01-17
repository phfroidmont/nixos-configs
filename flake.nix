{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
  };

  outputs = { self, home-manager, nixpkgs, nixpkgs-unstable }:
    let
      pkgs-unstable = nixpkgs-unstable.legacyPackages.x86_64-linux;
      commonModuleArgs = { pkgs, ... }: {
        _module.args.pkgs-unstable = import nixpkgs-unstable {
          inherit (pkgs.stdenv.targetPlatform) system;
          config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
            "corefonts"
            "steam"
            "steam-original"
            "steam-run"
          ];
        };
      };
    in
    {
      nixosConfigurations.nixos-desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit nixpkgs; inherit nixpkgs-unstable; };
        modules =
          [
            home-manager.nixosModules.home-manager
            commonModuleArgs
            ./hardware/desktop.nix
            ./profiles/base.nix
            ./users
            (
              {
                nixpkgs.overlays = [ (import ./overlay.nix { }) ];
                networking.hostName = "nixos-desktop";
                # Allow to externally control MPD
                networking.firewall.allowedTCPPorts = [ 6600 ];

                nix.registry.nixpkgs.flake = nixpkgs;

                system.stateVersion = "19.09";
              }
            )
          ];
      };

      nixosConfigurations.froidmpa-laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit nixpkgs; inherit nixpkgs-unstable; };
        modules =
          [
            home-manager.nixosModules.home-manager
            commonModuleArgs
            ./hardware/clevo-nl51ru.nix
            ./profiles/base.nix
            ./users
            (
              {
                nixpkgs.overlays = [ (import ./overlay.nix { }) ];
                networking.hostName = "froidmpa-laptop";

                nix.registry.nixpkgs.flake = nixpkgs;

                home-manager.users.froidmpa = { pkgs, config, ... }: {
                  services.network-manager-applet.enable = true;
                  services.blueman-applet.enable = true;
                  services.grobi = {
                    enable = true;
                    executeAfter = [ "${pkgs.systemd}/bin/systemctl --user restart stalonetray" "${pkgs.feh}/bin/feh --bg-fill ~/.wallpaper.png" ];
                    rules = [
                      {
                        name = "External HDMI";
                        outputs_connected = [ "HDMI-1" ];
                        configure_single = "HDMI-1";
                        primary = true;
                        atomic = true;
                      }
                      {
                        name = "Primary";
                        configure_single = "eDP";
                      }
                    ];
                  };
                };

                system.stateVersion = "21.05";
              }
            )

          ];
      };

      nixosConfigurations.rpi3 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules =
          [
            (
              { pkgs, ... }: {
                networking.hostName = "rpi3";

                nix.registry.nixpkgs.flake = nixpkgs;

                boot.loader.grub.enable = false;
                boot.loader.generic-extlinux-compatible.enable = true;
                boot.kernelParams = [ "cma=256M" ];

                fileSystems."/" =
                  {
                    device = "/dev/disk/by-label/NIXOS_SD";
                    fsType = "ext4";
                  };

                swapDevices = [{ device = "/swapfile"; size = 1024; }];

                services.openssh.enable = true;
                users.users.root.openssh.authorizedKeys.keyFiles = [
                  ./ssh_keys/phfroidmont-desktop.pub
                  ./ssh_keys/phfroidmont-laptop.pub
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
                      upstream_dns = [
                        "tls://doh.mullvad.net"
                        "[/lan/]192.168.1.1"
                        "[//]192.168.1.1"
                      ];
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

                networking.firewall.allowedTCPPorts = [ 53 ];
                networking.firewall.allowedUDPPorts = [ 53 ];

                environment.systemPackages = with pkgs; [
                  vim
                  htop
                ];

                nix = {
                  nixPath = [
                    "nixpkgs=${nixpkgs}"
                  ];
                };

                system.stateVersion = "22.05";
              }
            )
          ];
      };
    };
}
