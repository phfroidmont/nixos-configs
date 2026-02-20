{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.desktop.file-manager;
in
{
  options.modules.desktop.file-manager = {
    enable = lib.my.mkBoolOpt false;
  };
  config = lib.mkIf cfg.enable {
    home-manager.users.${config.user.name} = {

      programs.yazi = {
        enable = true;
        package = pkgs.yazi;
        enableZshIntegration = true;
        shellWrapperName = "y";
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
        keymap = {
          manager.prepend_keymap = [
            {
              on = [ "<C-s>" ];
              run = ''shell "$SHELL" --block --confirm'';
              desc = "Open shell here";
            }
            {
              on = [ "y" ];
              run = [
                "yank"
                ''
                  shell --confirm 'for path in "$@"; do echo "file://$path"; done | wl-copy -t text/uri-list'
                ''
              ];
              desc = "Copy files to clipboard";
            }
          ];
          input.prepend_keymap = [
            {
              on = [ "<Esc>" ];
              run = "close";
              desc = "Cancel input";
            }
          ];
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
        packages = with pkgs; [
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
