{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.desktop.themes.gtk;

  gruvboxPlus = pkgs.stdenv.mkDerivation rec {
    name = "gruvbox-plus";
    version = "5.1";
    src = pkgs.fetchurl {
      url = "https://github.com/SylEleuth/gruvbox-plus-icon-pack/releases/download/v${version}/gruvbox-plus-icon-pack-${version}.zip";
      sha256 = "1n3hqwk1mqaj8vbmy0pqbiq6v5jqrhmhin506xbpnccl28f907j0";
    };
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out
      ${pkgs.unzip}/bin/unzip $src -d $out/
    '';

  };
in
{
  options.modules.desktop.themes.gtk = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {

    systemd.packages = [ pkgs.dconf ];

    services.dbus.packages = with pkgs; [ dconf ];

    home-manager.users.${config.user.name} = {

      gtk = {
        enable = true;
        cursorTheme = {
          package = pkgs.unstable.paper-icon-theme;
          name = "Paper";
        };
        theme = {
          package = pkgs.unstable.adw-gtk3;
          name = "adw-gtk3";
        };
        iconTheme = {
          package = gruvboxPlus;
          name = "GruvboxPlus";
        };
      };

      xdg.configFile = {
        "gtk-3.0/gtk.css" = {
          source = ./gtk.css;
        };
        "gtk-4.0/gtk.css" = {
          source = ./gtk.css;
        };
      };

      home = {
        pointerCursor = {
          package = pkgs.unstable.paper-icon-theme;
          name = "Paper";
          size = 24;
          gtk.enable = true;
          x11.enable = true;
        };
      };
    };
  };
}
