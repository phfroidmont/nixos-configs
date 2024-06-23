{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    nix-doom-emacs.url = "github:nix-community/nix-doom-emacs";
    gruvbox-gtk-theme = {
      url = "github:Fausto-Korpsvart/Gruvbox-GTK-Theme";
      flake = false;
    };
    gruvbox-kvantum-theme = {
      url = "github:sachnr/gruvbox-kvantum-themes";
      flake = false;
    };
    flameshot-git = {
      url = "github:flameshot-org/flameshot";
      flake = false;
    };
  };

  outputs = inputs@{ self, home-manager, nixpkgs, nixpkgs-unstable, ... }:
    let
      inherit (lib.my) mapModules mapModulesRec mkHost mapHosts;

      system = "x86_64-linux";

      mkPkgs = pkgs: extraOverlays:
        import pkgs {
          inherit system;
          config.allowUnfreePredicate = pkg:
            builtins.elem (pkgs.lib.getName pkg) [
              "corefonts"
              "steam"
              "steam-original"
              "steam-run"
            ];
          overlays = extraOverlays ++ (pkgs.lib.attrValues self.overlays);
        };
      pkgs = mkPkgs nixpkgs [ self.overlay ];
      pkgs-unstable = mkPkgs nixpkgs-unstable [ ];

      lib = nixpkgs.lib.extend (self: super: {
        my = import ./lib {
          inherit pkgs inputs;
          lib = self;
        };
      });
    in {
      lib = lib.my;

      overlay = final: prev: { unstable = pkgs-unstable; };

      overlays = { my = (import ./overlay.nix); };

      nixosConfigurations = (mapHosts ./hosts { }) // {
        rpi3 = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit inputs; };
          modules = [ ./hosts/rpi3/default.nix ];
        };
      };
    };
}
