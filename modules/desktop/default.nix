{ inputs, config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let
  cfg = config.modules.desktop;
  wallpaper = pkgs.fetchurl {
    url =
      "https://raw.githubusercontent.com/AngelJumbo/gruvbox-wallpapers/main/wallpapers/irl/houseonthesideofalake.jpg";
    sha256 = "sha256-obKI4qZvucogqRCl51lwV9X8SRaMqcbBwWMfc9TupIo=";
  };
in {
  config = mkIf config.services.xserver.enable {

    fonts = {
      packages = with pkgs.unstable; [
        corefonts # Microsoft free fonts
        (nerdfonts.override { fonts = [ "Meslo" "NerdFontsSymbolsOnly" ]; })
      ];
      fontconfig.defaultFonts = { monospace = [ "MesloLGS Nerd Font Mono" ]; };
    };

    programs.adb.enable = true;

    programs.ssh.startAgent = true;

    services.udisks2.enable = true;

    home-manager.users.${config.user.name} = {

      xsession = {
        enable = true;
        initExtra = ''
          ${pkgs.feh}/bin/feh --bg-fill ${wallpaper}
          keepassxc &
        '';
        numlock.enable = true;
      };

      services = {
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
          lockCmd = "${pkgs.i3lock}/bin/i3lock -e -f -c 000000 -i ${wallpaper}";
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
        joshuto = {
          enable = true;
          package = with pkgs;
            writeShellScriptBin "joshuto" ''
              export joshuto_wrap_id="$$"
              export joshuto_wrap_tmp="$(mktemp -d -t joshuto-wrap-$joshuto_wrap_id-XXXXXX)"
              export joshuto_wrap_preview_meta="$joshuto_wrap_tmp/preview-meta"
              export ueberzug_pid_file="$joshuto_wrap_tmp/pid"
              export ueberzug_img_identifier="preview"
              export ueberzug_socket=""
              export ueberzug_pid=""

              function start_ueberzugpp {
                  ## Adapt Überzug++ options here. For example, remove the '--no-opencv' or set another output method.
                  ${ueberzugpp}/bin/ueberzug layer --no-stdin --pid-file "$ueberzug_pid_file" --no-opencv &>/dev/null
                  export ueberzug_pid="$(cat "$ueberzug_pid_file")"
                  export ueberzug_socket=/tmp/ueberzugpp-"$ueberzug_pid".socket
                  mkdir -p "$joshuto_wrap_preview_meta"
              }

              function stop_ueberzugpp {
                  remove_image
                  ${ueberzugpp}/bin/ueberzug cmd -s "$ueberzug_socket" -a exit
                  kill "$ueberzug_pid"
                  rm -rf "$joshuto_wrap_tmp"
              }

              function show_image {
                  ${ueberzugpp}/bin/ueberzug cmd -s "$ueberzug_socket" -a add -i "$ueberzug_img_identifier" -x "$2" -y "$3" --max-width "$4" --max-height "$5" -f "$1" &>/dev/null
              }

              function remove_image {
                  ${ueberzugpp}/bin/ueberzug cmd -s "$ueberzug_socket" -a remove -i "$ueberzug_img_identifier" &>/dev/null
              }

              function get_preview_meta_file {
                  echo "$joshuto_wrap_preview_meta/$(echo "$1" | md5sum | sed 's/ //g')"
              }

              export -f get_preview_meta_file
              export -f show_image
              export -f remove_image

              if [ -n "$DISPLAY" ] && command -v ${ueberzugpp}/bin/ueberzug > /dev/null; then
                  trap stop_ueberzugpp EXIT QUIT INT TERM
                  start_ueberzugpp
              fi

              ${joshuto}/bin/joshuto "$@"
              exit $?
            '';
          settings = {
            xdg_open = true;
            xdg_open_fork = true;
            display = { show_icons = true; };
            # preview.preview_protocol = "kitty";
            preview.preview_script = ./files/joshuo_preview_file.sh;
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

      xdg.desktopEntries = {
        ocr = {
          name = "OCR image";
          exec = "${pkgs.writeScript "ocr" ''
            ${pkgs.xfce.xfce4-screenshooter}/bin/xfce4-screenshooter -r --save /dev/stdout | \
            ${pkgs.tesseract}/bin/tesseract -l eng+fre - - | \
            ${pkgs.xclip}/bin/xclip -sel clip
          ''}";
        };
      };

      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          "inode/directory" = "joshuto.desktop";

          "text/html" = "firefox.desktop";
          "x-scheme-handler/http" = "firefox.desktop";
          "x-scheme-handler/https" = "firefox.desktop";
          "x-scheme-handler/about" = "firefox.desktop";

          "image/png" = "feh.desktop";
          "image/webp" = "feh.desktop";
          "image/jpeg" = "feh.desktop";
          "image/gif" = "mpv.desktop";
          "image/*" = "feh.desktop";
          "audio/*" = "mpv.desktop";
          "video/*" = "mpv.desktop";

          "application/zip" = "ark.desktop";
          "application/rar" = "ark.desktop";
          "application/7z" = "ark.desktop";
          "application/*tar" = "ark.desktop";
          "application/pdf" = "org.pwmt.zathura-pdf-mupdf.desktop";

          "application/msword" = "onlyoffice-desktopeditors.desktop";
          "application/vnd.openxmlformats-officedocument.presentationml.presentation" =
            "onlyoffice-desktopeditors.desktop";
          "application/vnd.openxmlformats-officedocument*" =
            "onlyoffice-desktopeditors.desktop";

          "text/*" = "nvim.desktop";
        };
      };

      home = {

        keyboard = {
          layout = "fr";
          options = [ "caps:escape" ];
        };

        file = { ".wallpaper.jpg".source = wallpaper; };

        sessionVariables.EDITOR = "vim";

        packages = with pkgs.unstable; [
          xorg.xinit
          xorg.xwininfo
          xorg.xkill

          # Joshuto preview utils
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
          gnucash
          transmission-remote-gtk
          monero-gui

          scala-cli
          jdk
          jetbrains.idea-community
          httpie

          zsh-syntax-highlighting
          R
          tldr
          thefuck
          ark
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
