{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgsStable.url = "github:nixos/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    qmk-firmware = {
      url = "git+https://github.com/zsa/qmk_firmware.git?ref=firmware25&submodules=1";
      flake = false;
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
    meridian.url = "github:rynfar/meridian";
    herdr = {
      url = "github:herdrdev/herdr/v0.8.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    omarchy = {
      url = "github:basecamp/omarchy/981274b20af8e85c09845071ac33c6230909f119";
      flake = false;
    };
    quickshell = {
      url = "github:quickshell-mirror/quickshell/v0.3.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dankcalendar = {
      url = "github:AvengeMedia/dankcalendar/v1.6.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
              "zapp"
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
        my = import ./overlay.nix { inherit inputs; };
      };

      packages.${system} = {
        fos = pkgs.fos;
        voyager-firmware = pkgs.voyager-firmware;
        voyager-flash = pkgs.voyager-flash;
      };

      apps.${system}.voyager-flash = {
        type = "app";
        program = lib.getExe pkgs.voyager-flash;
        meta.description = "Build and flash the ZSA Voyager firmware";
      };

      checks.${system} = {
        fos = pkgs.fos.tests;
        mullvad-gateway =
          let
            gateway = import ./hosts/aegis/mullvad.nix { pkgs = stablePkgs; };
            wrapper = builtins.head gateway.environment.systemPackages;
          in
          stablePkgs.runCommand "mullvad-gateway-tests"
            {
              nativeBuildInputs = [
                stablePkgs.python3
                stablePkgs.bash
                stablePkgs.shellcheck
                stablePkgs.util-linux
              ];
            }
            ''
              export PYTHONDONTWRITEBYTECODE=1
              python3 -m unittest discover -s ${./hosts/aegis/mullvad} -p 'test_*.py'
              shellcheck ${wrapper}/bin/mullvad-gw ${./hosts/aegis/mullvad/test_wrapper.sh}
              bash ${./hosts/aegis/mullvad/test_wrapper.sh} ${wrapper}/bin/mullvad-gw
              touch "$out"
            '';
        pangolin-fallback =
          let
            fallback = self.nixosConfigurations.stellaris.config.systemd;
          in
          assert builtins.elem "multi-user.target" fallback.timers.pangolin-fallback-reconcile.wantedBy;
          assert builtins.elem "pangolin.service" fallback.timers.pangolin-fallback-reconcile.wantedBy;
          assert builtins.elem "pangolin.service" fallback.timers.pangolin-fallback-reconcile.partOf;
          assert builtins.elem "pangolin.service" fallback.services.wg-quick-pg-fallback.requisite;
          assert
            self.nixosConfigurations.stellaris.config.networking.wg-quick.interfaces.pg-fallback.table == "off";
          assert
            !self.nixosConfigurations.stellaris.config.networking.wg-quick.interfaces.pg-fallback.autostart;
          pkgs.runCommand "pangolin-fallback-tests"
            {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.shellcheck
              ];
            }
            ''
              shellcheck ${./modules/services/pangolin-fallback.sh} ${./modules/services/pangolin-fallback-routing.sh} ${./tests/pangolin-fallback.test.sh} ${./tests/pangolin-fallback-routing.test.sh} ${./tests/pangolin-fallback-network.sh}
              bash ${./tests/pangolin-fallback.test.sh} ${./modules/services/pangolin-fallback.sh}
              bash ${./tests/pangolin-fallback-routing.test.sh} ${./modules/services/pangolin-fallback-routing.sh}
              touch "$out"
            '';
        voyager-firmware = pkgs.voyager-firmware;
        voyager-flash = pkgs.voyager-flash;
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
