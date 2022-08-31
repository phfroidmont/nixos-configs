{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
  };

  outputs = { self, home-manager, nixpkgs }: {

    nixosConfigurations.nixos-desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit nixpkgs; };
      modules =
        [
          home-manager.nixosModules.home-manager
          ./hardware/desktop.nix
          ./profiles/base.nix
          ./users
          (
            {
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
      specialArgs = { inherit nixpkgs; };
      modules =
        [
          home-manager.nixosModules.home-manager
          ./hardware/clevo-nl51ru.nix
          ./profiles/base.nix
          ./users
          (
            {
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
  };
}
