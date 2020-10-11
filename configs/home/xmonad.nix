{ config, lib, pkgs, ... }:
{
  xsession = {
    enable = true;
    windowManager.xmonad = {
      enable = true;
      enableContribAndExtras = true;
      config = ./files/xmonad.hs;
    };
    initExtra = ''
      keepassxc &
    '';
    numlock.enable = true;
  };
  nixpkgs.config.packageOverrides = pkgs: {
    ncmpcpp = pkgs.ncmpcpp.override {visualizerSupport = true;};
  };

  home = {
    sessionVariables = {
      EDITOR = "vim";
      QT_AUTO_SCREEN_SCALE_FACTOR = "0";
    };
    packages = with pkgs; [
      haskellPackages.xmobar
      ncmpcpp
      mpc_cli
      pulsemixer
      feh
      xorg.xbacklight
      xorg.xinit
      xorg.xwininfo
      xorg.xkill
      scrot
      numix-gtk-theme

      # Ranger preview utils
      w3m
      xclip
      odt2txt
    ];
    keyboard = {
      layout = "fr";
      options = ["caps:escape"];
    };
    file = {
      ".wallpaper.png".source = ./files/wallpaper.png;
      ".xmonad/xmobarrc".source = ./files/xmobarrc;
      ".config/ncmpcpp" = {
        source = ./files/ncmpcpp;
        recursive = true;
      };
      ".xmonad/scripts" = {
        source = ./files/scripts;
        recursive = true;
      };
      ".themes/oomox-gruvmox-dark-medium-default" = {
        source = ./files/oomox-gruvmox-dark-medium-default;
        recursive = true;
      };
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
  services = {
    mpd = {
      enable = true;
      musicDirectory = "${config.home.homeDirectory}/Nextcloud/Media/Music";
      extraConfig = ''
      max_output_buffer_size "16384"
      auto_update "yes"
      audio_output {
          type  "pulse"
          name  "pulse audio"
          device         "pulse"
          mixer_type      "hardware"
      }
      audio_output {
          type            "alsa"
          name            "alsa"
      }
      audio_output {
          type            "fifo"
          name            "toggle_visualizer"
          path            "/tmp/mpd.fifo"
          format          "44100:16:2"
      }
      '';
    };
    stalonetray = {
      enable = true;
      config = {
        geometry = "1x1-5+0";
        background = "#000000";
      transparent = true;
      grow_gravity = "E";
      icon_gravity = "E";
      icon_size = "24";
      kludges =  "force_icons_size";
      };
    };
    unclutter.enable = true;
    pasystray.enable = true;
    dunst = {
      enable = true;
      settings = {
        global = {
        monitor = 0;
          geometry = "350x5-30+50";
          transparency = 10;
          font = "monospace 14";
          idle_threshold = 120;
          allow_markup = "yes";
          format = "<b>%s</b>\n%b";
          show_age_threshold = 300;
          word_wrap = "yes";
          sticky_history = "yes";
          sort = "yes";
        };
        frame = {
            width = 3;
          color = "#ebdbb2";
        };
        shortcuts = {
          close = "ctrl+space";
          close_all = "ctrl+shift+space";
          history = "ctrl+grave";
          context = "ctrl+shift+period";
        };
        urgency_low = {
          foreground = "#ebdbb2";
          background = "#32302f";
          timeout = 10;
        };
        urgency_normal = {
          foreground = "#ebdbb2";
          background = "#32302f";
          timeout = 10;
        };
        urgency_critical = {
          foreground = "#ebdbb2";
          background = "#32302f";
          timeout = 10;
        };
      };
    };
    screen-locker = {
      enable = true;
      inactiveInterval = 5;
      lockCmd = "\${pkgs.i3lock}/bin/i3lock -e -f -c 000000 -i ~/.wallpaper.png";
    };
  };
  programs = {
    rofi = {
      enable = true;
      theme = "gruvbox-dark";
      terminal = "urxvt";
    };
    urxvt = {
      enable = true;
      package = pkgs.rxvt_unicode-with-plugins;
      fonts = ["xft:monospace:size=12:antialias=true"];
      scroll = {
        bar.enable = false;
        lines = 65535;
      };
      keybindings = {
        "Shift-Control-C" = "eval:selection_to_clipboard";
        "Shift-Control-V" = "eval:paste_clipboard";
      };
      extraConfig = {
        "perl-ext-common" =     "default,clipboard,matcher,resize-font";
        "background" =          "rgba:28ff/28ff/28ff/cf00";
        "foreground" =          "#ebdbb2";
        "color0" =              "#282828";
        "color8" =              "#928374";
        "color1" =              "#cc241d";
        "color9" =              "#fb4934";
        "color2" =              "#98971a";
        "color10" =             "#b8bb26";
        "color3" =              "#d79921";
        "color11" =             "#fabd2f";
        "color4" =              "#458588";
        "color12" =             "#83a598";
        "color5" =              "#b16286";
        "color13" =             "#d3869b";
        "color6" =              "#689d6a";
        "color14" =             "#8ec07c";
        "color7" =              "#a89984";
        "color15" =             "#ebdbb2";
        "termName" =            "rxvt-256color";
        "letterSpace" =         "-1";
        "internalBorder" =      "10";
        "depth" =               "32";
        "resize-font.smaller" = "C-Down";
        "resize-font.bigger" =  "C-Up";
      };
    };
  };

}
