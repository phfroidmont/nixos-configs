{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  modules = {
    desktop = {
      wm.enable = true;
      defaultBrowser = "brave-browser";
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
      kanata.enable = true;
    };
    media = {
      mpd.enable = true;
      ncmpcpp.enable = true;
      emulators.gc.enable = true;
      steam.enable = true;
      lutris.enable = true;
    };
    ai.opencode.enable = true;
  };

  services.tlp.enable = true;

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
      wayland.windowManager.hyprland.settings = {
        monitor = [
          "eDP-1, 2560x1600@240, 0x0, 1.6"
          "desc:Microstep MPG321UX OLED 0x01010101, 3840x2160@239.99001, auto-right, 1.6"
          ", preferred, auto, 1"
        ];

        workspace = [
          "w[tv1], gapsout:0, gapsin:0"
          "f[1], gapsout:0, gapsin:0"
        ];
        windowrule = [
          "border_size 0, match:float 0, match:workspace w[tv1]"
          "rounding 0, match:float 0, match:workspace w[tv1]"
          "border_size 0, match:float 0, match:workspace f[1]"
          "rounding 0, match:float 0, match:workspace f[1]"
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

  services.openssh = {
    enable = true;
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
