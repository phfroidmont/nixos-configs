{ inputs, config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop;
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
          ${pkgs.feh}/bin/feh --bg-fill ${./wallpaper.png}
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
          lockCmd =
            "${pkgs.i3lock}/bin/i3lock -e -f -c 000000 -i ${./wallpaper.png}";
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
          settings = {
            xdg_open = true;
            xdg_open_fork = true;
            preview.preview_script = ./files/joshuo_preview_file.sh;
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

        file = { ".wallpaper.png".source = ./wallpaper.png; };

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
