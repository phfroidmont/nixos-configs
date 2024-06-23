{ config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.file-manager;
in {
  options.modules.desktop.file-manager = { enable = mkBoolOpt false; };
  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = {

      programs.yazi = {
        enable = true;
        enableZshIntegration = true;
        settings = {
          manager = {
            sort_by = "alphabetical";
            linemode = "mtime";
          };
          preview = {
            max_width = 1200;
            max_height = 1800;
          };
        };
        theme = {
          status = {
            separator_open = "";
            separator_close = "";
            separator_style = {
              fg = "black";
              bg = "black";
            };
          };
        };
      };

      programs.zoxide = {
        enable = true;
        enableZshIntegration = true;
      };

      home = {
        packages = with pkgs.unstable; [
          ffmpegthumbnailer
          unar
          poppler
          fd
          ripgrep
          ueberzugpp
          exiftool
          chafa
          xdg-utils
        ];
      };
    };
  };
}
