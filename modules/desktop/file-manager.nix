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
