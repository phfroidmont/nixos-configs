{ config, lib, pkgs, ... }:
{
  xsession = {
    enable = true;
    windowManager.xmonad = {
      enable = true;
      enableContribAndExtras = true;
      config = ./files/xmonad.hs;
    };
  };
  nixpkgs.config.packageOverrides = pkgs: {
    ncmpcpp = pkgs.ncmpcpp.override {visualizerSupport = true;};
  };
  home.packages = with pkgs; [
    haskellPackages.xmobar
    ncmpcpp
    mpc_cli
    pulsemixer
    feh
    xorg.xinit
    xorg.xwininfo
    xorg.xkill
    scrot
  ];
  home.keyboard = {
    layout = "fr";
    options = ["caps:escape"];
  };
  home.file.".xmonad/xmobarrc".source = ./files/xmobarrc;
  home.file.".config/ncmpcpp" = {
    source = ./files/ncmpcpp;
    recursive = true;
  };
  home.file.".xmonad/scripts" = {
    source = ./files/scripts;
    recursive = true;
  };
  services.gpg-agent = { enable = true; enableSshSupport = true; };
  services.gnome-keyring = {
    enable = true;
    components = ["pkcs11" "secrets"];
  };
  services.mpd = {
    enable = true;
    musicDirectory = "${config.home.homeDirectory}/Nextcloud/Media/Music";
  };
  programs.rofi = {
    enable = true;
    theme = "gruvbox-dark";
    terminal = "urxvt";
  };

  programs.urxvt = {
    enable = true;
    fonts = ["xft:monospace:size=12:antialias=true"];
    scroll = {
      bar.enable = false;
      lines = 65535;
    };
    extraConfig = {
      "background" =     "rgba:28ff/28ff/28ff/cf00";
      "foreground" =     "#ebdbb2";
      "color0" =         "#282828";
      "color8" =         "#928374";
      "color1" =         "#cc241d";
      "color9" =         "#fb4934";
      "color2" =         "#98971a";
      "color10" =        "#b8bb26";
      "color3" =         "#d79921";
      "color11" =        "#fabd2f";
      "color4" =         "#458588";
      "color12" =        "#83a598";
      "color5" =         "#b16286";
      "color13" =        "#d3869b";
      "color6" =         "#689d6a";
      "color14" =        "#8ec07c";
      "color7" =         "#a89984";
      "color15" =        "#ebdbb2";
      "termName" =       "rxvt-256color";
      "letterSpace" =    "-1";
      "internalBorder" = "10";
      "depth" =          "32";
    };
  };

  services.compton.enable = true;
  services.stalonetray = {
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
  services.unclutter.enable = true;
  services.pasystray.enable = true;
  services.dunst = {
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
}