{ config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.joshuto;
in {
  options.modules.desktop.joshuto = { enable = mkBoolOpt false; };
  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = {
      programs.joshuto = {
        enable = true;
        package = with pkgs;
          writeShellApplication {
            name = "joshuto";
            runtimeInputs = [ ueberzugpp joshuto trash-cli xclip fzf ];
            text = builtins.readFile ./files/joshuto_wrapper.sh;
          };
        settings = {
          xdg_open = true;
          xdg_open_fork = true;
          display = { show_icons = true; };
          preview.preview_script = with pkgs;
            "${
              writeShellApplication {
                name = "joshuto-preview";
                runtimeInputs = [
                  file
                  catdoc
                  pandoc
                  mu
                  djvulibre
                  exiftool
                  mediainfo
                  atool
                  gnutar
                  poppler_utils
                  libtransmission
                  w3m
                ];
                text = builtins.readFile ./files/joshuto_preview_file.sh;
              }
            }/bin/joshuto-preview";
          preview.preview_shown_hook_script = with pkgs;
            writeScript "on_preview_shown" ''
              #!/usr/bin/env bash
              test -z "$joshuto_wrap_id" && exit 1;

              path="$1"       # Full path of the previewed file
              x="$2"          # x coordinate of upper left cell of preview area
              y="$3"          # y coordinate of upper left cell of preview area
              width="$4"      # Width of the preview pane (number of fitting characters)
              height="$5"     # Height of the preview pane (number of fitting characters)

              # Find out mimetype and extension
              mimetype=$(${file}/bin/file --mime-type -Lb "$path")
              extension=$(echo "''${path##*.}" | awk '{print tolower($0)}')

              case "$mimetype" in
                  image/png | image/jpeg)
                      show_image "$path" $x $y $width $height
                      ;;
                  *)
                      remove_image

              esac
            '';
          preview.preview_removed_hook_script =
            pkgs.writeScript "on_preview_removed" ''
              #!/usr/bin/env bash
              test -z "$joshuto_wrap_id" && exit 1;
              remove_image'';
        };
      };
    };
  };
}
