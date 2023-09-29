{ inputs, config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop;
in {
  config = mkIf config.services.xserver.enable {

    fonts = {
      fonts = with pkgs.unstable; [
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
      };

      xdg.configFile = {
        "ranger" = {
          source = ./files/ranger;
          recursive = true;
        };
        "ranger/plugins" = {
          source = builtins.fetchGit {
            url = "git://github.com/phfroidmont/ranger_devicons.git";
            rev = "e02b6a3203411b76616a0e4328245bf8b47c5dcc";
          };
          recursive = true;
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

          # Ranger preview utils
          w3m
          xclip
          odt2txt

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

          jdk
          jetbrains.idea-community
          httpie

          zsh-syntax-highlighting
          ranger
          R
          tldr
          thefuck
          atool
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
