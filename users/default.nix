{ config, lib, pkgs, ... }:
{

  environment.pathsToLink = [ "/share/zsh" ];
  home-manager.users.froidmpa = { pkgs, config, ... }: {
    nixpkgs.config = {
      allowUnfree = true;
      packageOverrides = pkgs: {
        ncmpcpp = pkgs.ncmpcpp.override { visualizerSupport = true; };
        firefox = pkgs.firefox.override { pkcs11Modules = [ pkgs.eid-mw ]; };
        lutris-unwrapped = pkgs.lutris-unwrapped.overridePythonAttrs (
          oldAttrs: rec {
            patches = [
              ./lutris_sort_new_with_model_fix.patch
            ];
          }
        );
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
      mpd = import ./froidmpa/mpd.nix { inherit config; };
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
      dunst = import ./froidmpa/dunst.nix { };
      screen-locker = {
        enable = true;
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
      rofi = {
        enable = true;
        theme = "gruvbox-dark";
        terminal = "urxvt";
      };
      urxvt = import ./froidmpa/urxvt.nix { inherit pkgs; };
      neovim = import ./froidmpa/neovim.nix { inherit pkgs; };
      bat.enable = true;
      jq.enable = true;
      fzf.enable = true;
      lesspipe.enable = true;
      zathura.enable = true;
      pazi.enable = true;
      htop = {
        enable = true;
        settings = {
          hide_userland_threads = true;
          highlight_base_name = true;
          vim_mode = true;
          fields = with config.lib.htop.fields;[
            PID
            USER
            M_RESIDENT
            M_SHARE
            STATE
            PERCENT_CPU
            PERCENT_MEM
            IO_RATE
            TIME
            COMM
          ];
        } // (
          with config.lib.htop; leftMeters [
            (bar "LeftCPUs2")
            (bar "CPU")
            (bar "Memory")
            (bar "Swap")
          ]
        ) // (
          with config.lib.htop; rightMeters [
            (bar "RightCPUs2")
            (text "Tasks")
            (text "LoadAverage")
            (text "Uptime")
          ]
        );
      };
      broot = {
        enable = true;
        enableZshIntegration = true;
      };
      command-not-found.enable = true;
      zsh = import ./froidmpa/zsh.nix { inherit pkgs; };
      direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;

      };
      vscode = {
        enable = true;
        package = pkgs.vscodium;
        extensions = (
          with pkgs.vscode-extensions; [
            pkief.material-icon-theme
            jnoortheen.nix-ide
            arrterian.nix-env-selector
            scala-lang.scala
            scalameta.metals
            hashicorp.terraform
            bradlc.vscode-tailwindcss
          ]
        );
        userSettings = {
          "editor.formatOnSave" = true;
          "editor.quickSuggestions" = {
            "strings" = true;
          };
          "tailwindCSS.includeLanguages" = {
            "scala" = "html";
          };
          "tailwindCSS.experimental.classRegex" = [
            [ "cls\\(([^)]*)\\)" "\"([^']*)\"" ]
          ];

          "files.autoSave" = "onFocusChange";
          "files.watcherExclude" = {
            "**/.bloop" = true;
            "**/.metals" = true;
            "**/.ammonite" = true;
          };
          "gruvboxMaterial.darkContrast" = "hard";
          "metals.millScript" = "mill";
          "nix.enableLanguageServer" = true;
          "terminal.integrated.confirmOnExit" = "hasChildProcesses";
          "terraform.languageServer" = {
            "external" = true;
            "pathToBinary" = "";
            "args" = [
              "serve"
            ];
            "maxNumberOfProblems" = 100;
            "trace.server" = "off";
          };
          "workbench.colorTheme" = "Gruvbox Material Dark";
          "workbench.iconTheme" = "material-icon-theme";
        };
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
        mumble
        libreoffice-fresh
        thunderbird
        portfolio
        transmission-remote-gtk
        monero-gui

        jdk11
        jetbrains.idea-community
        jetbrains.idea-ultimate
        maven
        mill
        sbt
        geckodriver
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

        steam
        dolphinEmu
      ];
    };
  };
}
