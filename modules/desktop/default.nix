{ config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop;
in {
  config = mkIf config.services.xserver.enable {

    fonts = {
      fonts = with pkgs.unstable; [
        corefonts # Microsoft free fonts
        (nerdfonts.override { fonts = [ "Meslo" ]; })
      ];
      fontconfig.defaultFonts = { monospace = [ "MesloLGS Nerd Font Mono" ]; };
    };

    programs.adb.enable = true;

    programs.ssh.startAgent = true;

    services.udisks2.enable = true;

    systemd.packages = [ pkgs.dconf ];

    # Required for custom GTK themes
    services.dbus.packages = with pkgs; [ dconf ];

    home-manager.users.${config.user.name} = {

      xsession = {
        enable = true;
        initExtra = ''
          keepassxc &
        '';
        numlock.enable = true;
      };

      services = {
        picom = {
          backend = "glx";
          vSync = true;
          opacityRules = [
            # "100:class_g = 'Firefox'"
            # Art/image programs where we need fidelity
            "100:class_g = 'Gimp'"
            "100:class_g = 'Inkscape'"
            "100:class_g = 'aseprite'"
            "100:class_g = 'krita'"
            "100:class_g = 'feh'"
            "100:class_g = 'mpv'"
            "100:class_g = 'Rofi'"
            "100:class_g = 'Peek'"
            "99:_NET_WM_STATE@:32a = '_NET_WM_STATE_FULLSCREEN'"
          ];
          shadowExclude = [
            # Put shadows on notifications, the scratch popup and rofi only
            "! name~='(rofi|scratch|Dunst)$'"
          ];

          fade = true;
          fadeDelta = 1;
          fadeSteps = [ 1.0e-2 1.2e-2 ];
          shadow = true;
          shadowOffsets = [ (-10) (-10) ];
          shadowOpacity = 0.22;
          # activeOpacity = "1.00";
          # inactiveOpacity = "0.92";
          #
          settings = {
            blur-background-exclude = [
              "window_type = 'dock'"
              "window_type = 'desktop'"
              "class_g = 'Rofi'"
              "_GTK_FRAME_EXTENTS@:c"
            ];

            # Unredirect all windows if a full-screen opaque window is detected, to
            # maximize performance for full-screen windows. Known to cause
            # flickering when redirecting/unredirecting windows.
            unredir-if-possible = true;

            # GLX backend: Avoid using stencil buffer, useful if you don't have a
            # stencil buffer. Might cause incorrect opacity when rendering
            # transparent content (but never practically happened) and may not work
            # with blur-background. My tests show a 15% performance boost.
            # Recommended.
            glx-no-stencil = true;

            # Use X Sync fence to sync clients' draw calls, to make sure all draw
            # calls are finished before picom starts drawing. Needed on
            # nvidia-drivers with GLX backend for some users.
            xrender-sync-fence = true;

            shadow-radius = 12;
            # blur-background = true;
            # blur-background-frame = true;
            # blur-background-fixed = true;
            blur-kern = "7x7box";
            blur-strength = 320;
          };
        };
        nextcloud-client.enable = true;
        udiskie.enable = true;
        gpg-agent = {
          enable = true;
          enableSshSupport = false;
          pinentryFlavor = "gtk2";
        };
        unclutter.enable = true;
        screen-locker = {
          enable = false;
          inactiveInterval = 5;
          lockCmd =
            "${pkgs.i3lock}/bin/i3lock -e -f -c 000000 -i ~/.wallpaper.png";
        };
      };

      programs = {
        gpg.enable = true;
        git = {
          enable = true;
          userName = "Paul-Henri Froidmont";
          userEmail = "git.contact-57n2p@froidmont.org";
          signing = {
            key = lib.mkDefault "3AC6F170F01133CE393BCD94BE948AFD7E7873BE";
            signByDefault = true;
          };
          extraConfig = { init.defaultBranch = "master"; };
        };
        ssh = {
          enable = true;
          extraConfig = ''
            # Force IPv4 otherwise git will try to use IPv6 which doesn't play well through a VPN
            AddressFamily inet
          '';
        };
        bat.enable = true;
        jq.enable = true;
        fzf.enable = true;
        lesspipe.enable = true;
        zathura.enable = true;
        pazi.enable = true;

        broot = {
          enable = true;
          enableZshIntegration = true;
        };
        command-not-found.enable = true;
        direnv = {
          enable = true;
          enableZshIntegration = true;
          nix-direnv.enable = true;
        };
      };

      gtk = {
        enable = true;
        theme.name = "oomox-gruvmox-dark-medium-default";
        iconTheme.name = "oomox-gruvmox-dark-medium-default";
      };
      qt = {
        enable = true;
        platformTheme = "gtk";
      };

      home = {
        sessionVariables = { QT_AUTO_SCREEN_SCALE_FACTOR = "0"; };

        keyboard = {
          layout = "fr";
          options = [ "caps:escape" ];
        };

        file = {
          ".wallpaper.png".source = ./wallpaper.png;
          ".themes/oomox-gruvmox-dark-medium-default" = {
            source = ./files/oomox-gruvmox-dark-medium-default;
            recursive = true;
          };
          ".config/ranger" = {
            source = ./files/ranger;
            recursive = true;
          };
          ".config/ranger/plugins" = {
            source = builtins.fetchGit {
              url = "git://github.com/phfroidmont/ranger_devicons.git";
              rev = "e02b6a3203411b76616a0e4328245bf8b47c5dcc";
            };
            recursive = true;
          };
        };

        packages = with pkgs.unstable; [
          xorg.xinit
          xorg.xwininfo
          xorg.xkill
          numix-gtk-theme

          # Ranger preview utils
          w3m
          xclip
          odt2txt

          firefox
          brave
          keepassxc
          krita
          element-desktop
          mpv
          jellyfin-mpv-shim
          mumble
          libreoffice-fresh
          onlyoffice-bin
          thunderbird
          portfolio
          transmission-remote-gtk
          monero-gui

          jdk
          jetbrains.idea-community
          httpie

          zsh-syntax-highlighting
          ranger
          R
          tldr
          thefuck
          atool
          linuxPackages.perf
        ];
      };

      systemd.user.services.activitywatch = {
        Unit.Description = "Start ActivityWatch";
        Service.Type = "simple";
        Service.ExecStart = "${pkgs.unstable.activitywatch-bin}/bin/aw-server";
        Install.WantedBy = [ "default.target" ];
        Service.Restart = "on-failure";
        Service.RestartSec = 5;
      };
      systemd.user.services.activitywatch-afk = {
        Unit.Description = "Start ActivityWatch AFK";
        Service.Type = "simple";
        Service.ExecStart =
          "${pkgs.unstable.activitywatch-bin}/bin/aw-watcher-afk";
        Install.WantedBy = [ "default.target" ];
        Service.Restart = "on-failure";
        Service.RestartSec = 5;
      };
      systemd.user.services.activitywatch-window = {
        Unit.Description = "Start ActivityWatch Window";
        Service.Type = "simple";
        Service.ExecStart =
          "${pkgs.unstable.activitywatch-bin}/bin/aw-watcher-window";
        Install.WantedBy = [ "default.target" ];
        Service.Restart = "on-failure";
        Service.RestartSec = 5;
      };
    };
  };
}
