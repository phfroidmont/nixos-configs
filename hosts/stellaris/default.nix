{
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ];

  modules = {
    applications.browser = "brave";
    desktop = {
      wm.enable = true;
    };
    editor = {
      vim.enable = true;
      emacs.enable = true;
    };
    services = {
      nix-auth.enable = true;
      flatpak.enable = true;
      belgian-eid.enable = true;
      docker.enable = true;
      libvirt.enable = true;
      languagetool.enable = true;
      work-proxy.enable = true;
      kanata.enable = false;
      hermesAccounting = {
        enable = false;
        git = {
          remoteUrl = "ssh://forgejo@forge.froidmont.org/phfroidmont/pta.git";
          forgejoHost = "forge.froidmont.org";
          branch = "master";
        };
      };
    };
    media = {
      mpd.enable = true;
      ncmpcpp.enable = true;
      emulators.gc.enable = true;
      steam.enable = true;
      lutris.enable = false;
    };
    ai.opencode.enable = true;
  };

  programs.nh = {
    enable = true;
    flake = "/home/phfroidmont/Projects/nixos-configs";
  };

  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  hardware.cpu.amd.updateMicrocode = true;
  hardware.tuxedo-drivers.enable = true;
  hardware.tuxedo-rs = {
    enable = true;
    tailor-gui.enable = true;
  };

  # Keep LED state deterministic:
  # - force key kbd_backlight_94 back to the default profile
  # - force the lightbar to an off profile
  systemd.services.tailord-led-profile-fix = {
    description = "Fix TUXEDO LED profile quirks";
    requiredBy = [ "tailord.service" ];
    before = [ "tailord.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -eu
      ${pkgs.python3}/bin/python - <<'PY'
      import json
      from pathlib import Path

      profile_path = Path("/etc/tailord/profiles/default.json")
      if not profile_path.exists():
          raise SystemExit(0)

      data = json.loads(profile_path.read_text())
      changed = False

      for led in data.get("leds", []):
          if led.get("function") == "kbd_backlight_94" and led.get("profile") != "default":
              led["profile"] = "default"
              changed = True
          if led.get("function") == "lightbar" and led.get("profile") != "off":
              led["profile"] = "off"
              changed = True

      off_profile_path = Path("/etc/tailord/keyboard/off.json")
      off_profile = '{"Single":{"r":0,"g":0,"b":0}}'
      if (not off_profile_path.exists()) or off_profile_path.read_text().strip() != off_profile:
          off_profile_path.write_text(off_profile)
          changed = True

      if changed:
          profile_path.write_text(json.dumps(data, separators=(",", ":")))
      PY
    '';
  };

  hardware = {
    acpilight.enable = true;
    bluetooth = {
      enable = true;
      # Enable A2DP Sink
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
        };
      };
    };
  };

  networking.networkmanager.enable = true;

  services.blueman.enable = true;

  services.logind.settings.Login.HandleLidSwitch = "ignore";

  user.name = "phfroidmont";

  home-manager.users.${config.user.name} =
    { ... }:
    {
      services.network-manager-applet.enable = true;
      services.blueman-applet.enable = true;
      services.kanshi = {
        enable = true;
        settings = [
          {
            profile.name = "docked-dual";
            profile.outputs = [
              {
                criteria = "Microstep MPG321UX OLED 0x01010101";
                mode = "3840x2160@239.99Hz";
                position = "0,0";
                scale = 1.6;
              }
              {
                criteria = "LG Electronics LG Ultra HD 0x0001AEB0";
                mode = "3840x2160@59.997Hz";
                position = "2400,0";
                scale = 1.6;
              }
              {
                criteria = "eDP-1";
                status = "disable";
              }
            ];
          }
          {
            profile.name = "docked";
            profile.outputs = [
              {
                criteria = "Microstep MPG321UX OLED 0x01010101";
                mode = "3840x2160@239.99Hz";
                position = "0,0";
                scale = 1.6;
              }
              {
                criteria = "eDP-1";
                status = "disable";
              }
            ];
          }
          {
            profile.name = "laptop";
            profile.outputs = [
              {
                criteria = "eDP-1";
                mode = "2560x1600@240Hz";
                position = "0,0";
                scale = 1.6;
              }
            ];
          }
        ];
      };

      wayland.windowManager.hyprland.settings = {
        monitor = [
          {
            output = "eDP-1";
            mode = "2560x1600@240";
            position = "0x0";
            scale = 1.6;
          }
          {
            output = "desc:HP Inc. HP E24m G4 CNC2191PK5";
            mode = "preferred";
            position = "auto-left";
            scale = 1;
          }
          {
            output = "desc:Microstep MPG321UX OLED 0x01010101";
            mode = "3840x2160@239.99001";
            position = "auto-right";
            scale = 1.6;
          }
          {
            output = "";
            mode = "preferred";
            position = "auto";
            scale = 1;
          }
        ];

        workspace_rule = [
          {
            workspace = "w[tv1]";
            gaps_out = 0;
            gaps_in = 0;
          }
          {
            workspace = "f[1]";
            gaps_out = 0;
            gaps_in = 0;
          }
        ];
        window_rule = [
          {
            match = {
              float = false;
              workspace = "w[tv1]";
            };
            border_size = 0;
            rounding = 0;
          }
          {
            match = {
              float = false;
              workspace = "f[1]";
            };
            border_size = 0;
            rounding = 0;
          }
        ];
      };
    };

  services.pipewire.wireplumber.extraConfig = {
    "monitor.bluez.properties" = {
      "bluez5.enable-sbc-xq" = true;
      "bluez5.enable-msbc" = true;
      "bluez5.enable-hw-volume" = true;
      "bluez5.roles" = [
        "hsp_hs"
        "hsp_ag"
        "hfp_hf"
        "hfp_ag"
      ];
    };
  };

  services.tailscale.enable = true;

  environment.systemPackages = [
    pkgs.fos
    (pkgs.writeShellScriptBin "aegis-vpn" ''
      set -euo pipefail

      TARGET="''${AEGIS_SSH_TARGET:-admin@192.168.1.1}"

      if [[ $# -lt 1 ]]; then
        echo "Usage: aegis-vpn <up|down|status|list|switch SERVER>" >&2
        exit 1
      fi

      printf -v remote_args '%q ' "$@"
      exec ${pkgs.openssh}/bin/ssh "$TARGET" "sudo /run/current-system/sw/bin/mullvad-gw ''${remote_args}"
    '')
  ];

  services.openssh = {
    enable = false;
    settings.PasswordAuthentication = false;
    listenAddresses = [
      {
        # Tailscale interface
        addr = "100.64.0.5";
        port = 22;
      }
    ];
  };
  users.users.${config.user.name} = {
    openssh.authorizedKeys.keyFiles = [
      ../../ssh_keys/phfroidmont-desktop.pub
    ];
    extraGroups = [ "video" ];
  };

  system.stateVersion = "25.05";
}
