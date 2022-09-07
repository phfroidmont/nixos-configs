{ config, lib, pkgs, ... }:
{

  environment.pathsToLink = [ "/share/zsh" ];
  home-manager.users.froidmpa = { pkgs, config, ... }: {

    imports = [
      ./froidmpa/alacritty.nix
      ./froidmpa/neovim.nix
      ./froidmpa/mpd.nix
      ./froidmpa/dunst.nix
      ./froidmpa/htop.nix
      ./froidmpa/zsh.nix
      ./froidmpa/vscode.nix
    ];

    nixpkgs.config = {
      allowUnfree = true;
      packageOverrides = pkgs: {
        ncmpcpp = pkgs.ncmpcpp.override { visualizerSupport = true; };
        firefox = pkgs.firefox.override { pkcs11Modules = [ pkgs.eid-mw ]; };
      };
    };

    xsession = {
      enable = true;
      windowManager.xmonad = {
        enable = true;
        enableContribAndExtras = true;
        config = ./files/xmonad.hs;
      };
      initExtra = ''
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
      stalonetray = {
        enable = true;
        config = {
          geometry = "1x1-5+0";
          background = "#000000";
          transparent = true;
          grow_gravity = "E";
          icon_gravity = "E";
          icon_size = "24";
          kludges = "force_icons_size";
        };
      };
      unclutter.enable = true;
      pasystray.enable = true;
      screen-locker = {
        enable = false;
        inactiveInterval = 5;
        lockCmd = "${pkgs.i3lock}/bin/i3lock -e -f -c 000000 -i ~/.wallpaper.png";
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
        extraConfig = {
          init.defaultBranch = "master";
        };
      };
      ssh = {
        enable = true;
        extraConfig = ''
          # Force IPv4 otherwise git will try to use IPv6 which doesn't play well through a VPN
          AddressFamily inet
        '';
      };
      rofi = {
        enable = true;
        theme = "gruvbox-dark";
        terminal = "alacritty";
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

    gtk = {
      enable = true;
      theme.name = "oomox-gruvmox-dark-medium-default";
      iconTheme.name = "oomox-gruvmox-dark-medium-default";
    };
    qt = {
      enable = true;
      platformTheme = "gtk";
    };

    home = {
      stateVersion = "20.09";

      sessionVariables = {
        EDITOR = "vim";
        QT_AUTO_SCREEN_SCALE_FACTOR = "0";
      };

      keyboard = {
        layout = "fr";
        options = [ "caps:escape" ];
      };

      file = {
        ".wallpaper.png".source = ./files/wallpaper.png;
        ".xmonad/xmobarrc".source = ./files/xmobarrc;
        ".config/ncmpcpp" = {
          source = ./files/ncmpcpp;
          recursive = true;
        };
        ".xmonad/scripts" = {
          source = ./files/scripts;
          recursive = true;
        };
        ".themes/oomox-gruvmox-dark-medium-default" = {
          source = ./files/oomox-gruvmox-dark-medium-default;
          recursive = true;
        };
        ".config/ranger" = {
          source = ./files/ranger;
          recursive = true;
        };
        ".config/ranger/plugins" = {
          source = builtins.fetchGit {
            url = "git://github.com/phfroidmont/ranger_devicons.git";
            rev = "e02b6a3203411b76616a0e4328245bf8b47c5dcc";
          };
          recursive = true;
        };
      };

      packages = with pkgs; [
        haskellPackages.xmobar
        i3lock
        ncmpcpp
        mpc_cli
        pulsemixer
        feh
        xorg.xbacklight
        xorg.xinit
        xorg.xwininfo
        xorg.xkill
        scrot
        numix-gtk-theme

        # Ranger preview utils
        w3m
        xclip
        odt2txt

        firefox
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
        exodus

        jdk
        httpie

        rnix-lsp
        nixpkgs-fmt

        zsh-syntax-highlighting
        ranger
        R
        tldr
        thefuck
        atool
        linuxPackages.perf

        glxinfo
        steam
        lutris
        dolphinEmu
      ];
    };
  };
}
