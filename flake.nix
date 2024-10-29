{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    nixvim = {
      url = "github:nix-community/nixvim/nixos-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vim-yazi = {
      url = "github:mikavilpas/yazi.nvim";
      flake = false;
    };
    vim-org-roam = {
      url = "github:chipsenkbeil/org-roam.nvim";
      flake = false;
    };
    flameshot-git = {
      url = "github:flameshot-org/flameshot";
      flake = false;
    };
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      inherit (lib.my) mapHosts;

      system = "x86_64-linux";

      mkPkgs =
        pkgs: extraOverlays:
        import pkgs {
          inherit system;
          config.allowUnfreePredicate =
            pkg:
            builtins.elem (pkgs.lib.getName pkg) [
              "corefonts"
              "steam"
              "steam-original"
              "steam-run"
            ];
          overlays = extraOverlays ++ (pkgs.lib.attrValues self.overlays);
        };

      pkgs = mkPkgs nixpkgs [ ];

      lib = nixpkgs.lib.extend (
        self: super: {
          my = import ./lib {
            inherit pkgs inputs;
            lib = self;
          };
        }
      );
    in
    {
      lib = lib.my;

      overlays = {
        my = import ./overlay.nix;
      };

      nixosConfigurations = (mapHosts ./hosts { }) // {
        rpi3 = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = {
            inherit inputs;
          };
          modules = [ ./hosts/rpi3/default.nix ];
        };
      };
    };
}
