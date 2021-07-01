{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
  };

  outputs = { self, home-manager, nixpkgs }: {

    nixosConfigurations.nixos-desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules =
        [
          home-manager.nixosModules.home-manager
          {
            imports = [
              ./hosts/nixos-desktop/configuration.nix
            ];

            system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
            nix.registry.nixpkgs.flake = nixpkgs;
          }
        ];
    };

    nixosConfigurations.froidmpa-laptop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules =
        [
          home-manager.nixosModules.home-manager
          {
            imports = [
              ./hosts/froidmpa-laptop/configuration.nix
            ];

            system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
            nix.registry.nixpkgs.flake = nixpkgs;
          }
        ];
    };

  };
}
