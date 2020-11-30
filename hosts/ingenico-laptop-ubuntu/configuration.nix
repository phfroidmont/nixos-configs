{ config, lib, pkgs, ... }:
{
  imports = [
    ../../configs/home/ubuntu-full.nix
  ];

  programs.home-manager.enable = true;
  home.username = "froidmpa";
  home.homeDirectory = "/home/froidmpa";

  services = {
    network-manager-applet.enable = true;
    blueman-applet.enable = true;
    grobi = {
      enable = true;
      executeAfter = ["${pkgs.systemd}/bin/systemctl --user restart stalonetray" "${pkgs.feh}/bin/feh --bg-fill ~/.wallpaper.png"];
      rules = [
        {
          name = "Work HDMI";
          outputs_connected = [ "HDMI-1" ];
          configure_single = "HDMI-1";
          primary = true;
          atomic = true;
        }
        {
          name = "Work USBC";
          outputs_connected = [ "DP-1" ];
          configure_single = "DP-1";
          primary = true;
          atomic = true;
        }
        {
          name = "Fallback";
          configure_single = "eDP-1";
        }
      ];
    };
    gpg-agent = {
      enable = true;
      enableSshSupport = true;
      #pinentryFlavor = "tty";
    };
  };
  programs = {
    git = {
      enable = true;
      userName  = "Paul-Henri Froidmont";
      userEmail = "paul-henri.froidmont@ingenico.com";
      signing = {
        key = "589ECB6FAA8FF1F40E579C9E1479473F99393013";
        signByDefault = true;
      };
    };
    gpg.enable = true;
  };
  fonts.fontconfig.enable = true;
  home = {
    sessionVariables = {
      QT_XCB_GL_INTEGRATION = "none"; # Fix "Could not initialize GLX" segfault
      LOCALE_ARCHIVE_2_11 = "$(nix-build --no-out-link \"<nixpkgs>\" -A glibcLocales)/lib/locale/locale-archive";
      LOCALE_ARCHIVE_2_27 = "$(nix-build --no-out-link \"<nixpkgs>\" -A glibcLocales)/lib/locale/locale-archive";
      LOCALE_ARCHIVE = "/usr/bin/locale";
    };
    file = {
      ".config/fontconfig/fonts.conf" = {
        source = ./fonts.conf;
      };
    };
  };

  home.stateVersion = "20.09";
}

