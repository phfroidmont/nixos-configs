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
in
{

  options.modules.desktop = {
    wallpaper = mkOption {
      type = types.path;
      default = wallpaper;
    };
  };

  config = mkIf config.modules.desktop.wm.enable {

    fonts = {
      packages = with pkgs.unstable; [
        corefonts # Microsoft free fonts
        noto-fonts-emoji
        meslo-lg
        (nerdfonts.override { fonts = [ "Meslo" "NerdFontsSymbolsOnly" ]; })
      ];
      fontconfig.defaultFonts = { monospace = [ "MesloLGS Nerd Font Mono" ]; };
    };

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
          pinentryPackage = pkgs.pinentry-gtk2;
        };
        unclutter.enable = true;
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

          "text/html" = "firefox.desktop";
          "x-scheme-handler/http" = "firefox.desktop";
          "x-scheme-handler/https" = "firefox.desktop";
          "x-scheme-handler/about" = "firefox.desktop";

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

        sessionVariables.EDITOR = "vim";

        packages = with pkgs.unstable; [
          brave
          ungoogled-chromium
          mullvad-browser
          keepassxc
          krita
          element-desktop
          swayimg
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

    };
  };
}
