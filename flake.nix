{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgsStable.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    vim-org-roam = {
      url = "github:chipsenkbeil/org-roam.nvim";
      flake = false;
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
    hermes-agent.url = "github:NousResearch/hermes-agent";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgsStable,
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
              "steam"
              "steam-original"
              "steam-run"
              "steam-unwrapped"
              "keymapp"
              "mongodb-compass"
              "nvidia-x11"
              "nvidia-settings"
              "idea"
            ];
          overlays = extraOverlays ++ (pkgs.lib.attrValues self.overlays);
        };

      pkgs = mkPkgs nixpkgs [ ];
      stablePkgs = mkPkgs nixpkgsStable [ ];

      lib = nixpkgs.lib.extend (
        self: super: {
          my = import ./lib {
            inherit pkgs inputs;
            lib = self;
          };
        }
      );

      stableLib = nixpkgsStable.lib.extend (
        self: super: {
          my = import ./lib {
            pkgs = stablePkgs;
            inherit inputs;
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
        aegis = stableLib.my.mkHost ./hosts/aegis/default.nix {
          nix.registry.nixpkgs.flake = stableLib.mkForce nixpkgsStable;
        };

        aegis-installer = stableLib.my.mkHost ./hosts/aegis-installer/default.nix {
          nix.registry.nixpkgs.flake = stableLib.mkForce nixpkgsStable;
        };
      };
    };
}
