{
  config,
  lib,
  pkgs,
  ...
}:

let
  wallpaper = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/AngelJumbo/gruvbox-wallpapers/main/wallpapers/photography/houseonthesideofalake.jpg";
    sha256 = "sha256-obKI4qZvucogqRCl51lwV9X8SRaMqcbBwWMfc9TupIo=";
  };
in
{

  options.modules.desktop = {
    wallpaper = lib.mkOption {
      type = lib.types.path;
      default = wallpaper;
    };

    defaultBrowser = lib.mkOption {
      type = lib.types.str;
      default = "firefox";
    };
  };

  config = lib.mkIf config.modules.desktop.wm.enable {

    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        noto-fonts-color-emoji
        meslo-lg
        pkgs.nerd-fonts.meslo-lg
        pkgs.nerd-fonts.symbols-only
      ];
      fontconfig.defaultFonts = {
        monospace = [ "MesloLGS Nerd Font Mono" ];
      };
    };

    security.pam.loginLimits = [
      {
        domain = "*";
        item = "nofile";
        type = "-";
        value = "65536";
      }
    ];

    programs.adb.enable = true;

    programs.ssh.startAgent = true;

    services.udisks2.enable = true;

    home-manager.users.${config.user.name} = {

      services = {
        nextcloud-client.enable = true;
        udiskie.enable = true;
        gpg-agent = {
          enable = true;
          enableSshSupport = false;
          pinentry.package = pkgs.pinentry-gtk2;
        };
        unclutter.enable = true;
      };

      programs = {
        gpg.enable = true;
        git = {
          enable = true;
          signing = {
            key = lib.mkDefault "3AC6F170F01133CE393BCD94BE948AFD7E7873BE";
            signByDefault = true;
          };
          settings = {
            user.name = "Paul-Henri Froidmont";
            user.email = "git.contact-57n2p@froidmont.org";
            init.defaultBranch = "master";
          };
        };
        ssh = {
          enable = true;
          enableDefaultConfig = false;
          matchBlocks."*" = {
            forwardAgent = false;
            addKeysToAgent = "no";
            compression = false;
            serverAliveInterval = 0;
            serverAliveCountMax = 3;
            hashKnownHosts = false;
            userKnownHostsFile = "~/.ssh/known_hosts";
            controlMaster = "no";
            controlPath = "~/.ssh/master-%r@%n:%p";
            controlPersist = "no";
          };
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

      xdg.desktopEntries = {
        ocr = {
          name = "OCR image";
          exec = "${pkgs.writeScript "ocr" ''
            ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - | \
            ${pkgs.tesseract}/bin/tesseract stdin stdout -l eng+fre | \
            ${pkgs.wl-clipboard}/bin/wl-copy
          ''}";
        };
      };

      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          "inode/directory" = "joshuto.desktop";

          "text/html" = "${config.modules.desktop.defaultBrowser}.desktop";
          "x-scheme-handler/http" = "${config.modules.desktop.defaultBrowser}.desktop";
          "x-scheme-handler/https" = "${config.modules.desktop.defaultBrowser}.desktop";
          "x-scheme-handler/about" = "${config.modules.desktop.defaultBrowser}.desktop";

          "image/png" = "swayimg.desktop";
          "image/webp" = "swayimg.desktop";
          "image/jpeg" = "swayimg.desktop";
          "image/gif" = "mpv.desktop";
          "image/*" = "swayimg.desktop";
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
          "application/vnd.openxmlformats-officedocument*" = "onlyoffice-desktopeditors.desktop";

          "text/*" = "nvim.desktop";
        };
      };

      home = {

        keyboard = {
          layout = "fr";
          options = [ "caps:escape" ];
        };

        sessionVariables = {
          EDITOR = "vim";
          NIXOS_OZONE_WL = 1;
        };

        packages =
          (with pkgs; [
            brave
            ungoogled-chromium
            mullvad-browser
            keepassxc
            krita
            swayimg
            mpv
            mumble
            libreoffice-fresh
            signal-desktop
            onlyoffice-desktopeditors
            thunderbird
            portfolio
            gnucash
            transmission-remote-gtk

            scala-cli
            beamMinimal27Packages.elixir
            jdk
            jetbrains.idea-oss
            jetbrains.idea
            httpie

            zsh-syntax-highlighting
            R
            tldr
            kdePackages.ark
            perf
            keymapp
            presenterm

            ledger-live-desktop
            monero-gui
          ])
          ++ [ pkgs.jellyfin-mpv-shim ];
      };

    };
    hardware.keyboard.zsa.enable = true;
    hardware.ledger.enable = true;
  };
}
