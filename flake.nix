{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vim-org-roam = {
      url = "github:chipsenkbeil/org-roam.nvim";
      flake = false;
    };
    # Workaround until nvim-treesitter main branch is used in nixpkgs
    nvim-treesitter-main.url = "github:iofq/nvim-treesitter-main";
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
              "steam-unwrapped"
              "keymapp"
              "mongodb-compass"
              "nvidia-x11"
              "nvidia-settings"
              "idea-ultimate"
            ];
          overlays =
            extraOverlays
            ++ (pkgs.lib.attrValues self.overlays)
            ++ [ inputs.nvim-treesitter-main.overlays.default ];
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
